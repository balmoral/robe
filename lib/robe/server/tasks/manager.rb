# Adapted from Volt. We don't use drb for now.

require 'singleton'
require 'json'
require 'timeout'     # ruby stdlib
require 'concurrent'  # concurrent-ruby gem

require 'robe/common/sockets'
require 'robe/common/promise'
require 'robe/server/config'
require 'robe/server/auth'
require 'robe/server/tasks/logger'
require 'robe/server/tasks/registry'

# The tasks module takes incoming messages from the
# task socket channel, dispatches them to the
# registered task block, and sends responses back
# to the client(s).

module Robe
  module Server
    module Tasks
      class Manager
        include Singleton

        def initialize
          @logger = Robe::Server::Tasks::Logger
          @registry = Robe.task_registry
          init_sockets_channel
          init_threads
        end

        private

        def logger
          @logger
        end

        def registry
          @registry
        end

        def task_channel
          sockets.task_channel
        end

        def sockets
          Robe.sockets
        end

        def init_sockets_channel
          # trace __FILE__, __LINE__, self, __method__
          sockets.on_channel(task_channel, :request) do |client:, content:|
            # trace __FILE__, __LINE__, self, __method__, " : client:#{client}, content: #{content}"
            process_request(client, content)
          end
        end

        def init_threads
          @timeout = Robe.config.task_timeout
          @thread_pool = if Robe.config.max_task_threads > 0
            Concurrent::CachedThreadPool.new(
              min_threads: [Robe.config.min_task_threads, 1].max,
              max_threads: Robe.config.max_task_threads
            )
          end
        end

        # Dispatch takes an incoming task from the client and runs
        # it on the server, returning the result to the client.
        # Tasks returning a promise will wait to return.
        def process_request(client, request) # , session)
          # trace __FILE__, __LINE__, self, __method__, "(#{client}, #{request})"
          request = request.symbolize_keys
          # trace __FILE__, __LINE__, self, __method__
          # dispatch the task in the thread pool, along with meta data.
          task = -> {
            perform_task(
              client: client,
              name: request[:task],
              args: request[:args],
              id: request[:id],
              user: request[:user],
              # session: session
            )
          }
          if @thread_pool
            @thread_pool.post do
              ::Thread.abort_on_exception = true # may have no effect
              task.call
            end
          else
            task.call
          end
        # rescue Exception => e
        #   msg = "#{__FILE__}[#{__LINE__}] : #{e}"
        #   Robe.logger.error(msg)
        #   raise e
        end

        # Perform the task, running inside of a worker thread.
        # user should be a hash with :id and :signature where
        # signature is a signed user user id
        def perform_task(client:, name:, args:, id:, user:)
          # trace __FILE__, __LINE__, self, __method__, "(client: #{client}, name: #{name}, args: #{args}, id: #{id}, user: #{user})"
          logger.performing(name, args) if Robe.config.log_tasks?
          start_time = Time.now.to_f
          resolve_task(name, args, user).then do |result, meta_data|
            send_response(client: client, task: name, id: id, result: result, error: nil, meta_data: meta_data)
            run_time = ((Time.now.to_f - start_time) * 1000).round(3)
            logger.performed(name, run_time, args) if Robe.config.log_tasks?
          end.fail do |error|
            logger.failed(name, args, metadata)
            begin
              # trace __FILE__, __LINE__, self, __method__, "  send_response(task: #{name}, id: #{id}, error: #{error})"
              send_response(client: client, task: name, id: id, error: error)
            rescue JSON::GeneratorError => e
              trace __FILE__, __LINE__, self, __method__, "  #{e}"
              # Convert the error into a string so it can be serialized to something.
              error = "#{error.class.to_s}: #{error.to_s}"
              send_response(client: client, task: name, id: id, error: error)
            end
          end
        end

        # Returns a promise.
        def resolve_task(task_name, args, user)
          # trace __FILE__, __LINE__, self, __method__, " task_name=#{task_name} args=#{args} meta_data=#{meta_data}"
          task = registry[task_name.to_sym]
          # trace __FILE__, __LINE__, self, __method__, " : #{task_name} => #{task}"
          if task
            args = args.dup.symbolize_keys
            block = task[:block]
            if task[:auth]
              error_stub = "Unauthorized #{task_name} request"
              return "#{error_stub}: missing user data.".to_promise_error if user.nil? || user.empty?
              user = user.symbolize_keys
              user_id = user[:id]
              return "#{error_stub}: missing user id.".to_promise_error if user_id.nil? || user_id.empty?
              user_signature = user[:signature]
              return "#{error_stub}: missing user signature.".to_promise_error if user_signature.nil? || user_signature.empty?
              is_valid = Robe.auth.valid_user_signature?(user_id, user_signature)
              return "#{error_stub}: invalid user signature.".to_promise_error unless is_valid
            end
            # trace __FILE__, __LINE__, self, __method__, " @timeout=#{@timeout}"
            Timeout.timeout(@timeout, Robe::TimeoutError) do
              trace __FILE__, __LINE__, self, __method__, " : user_signature=#{user_signature}"
              Robe.auth.thread_user_signature = user_signature if user_signature # this also sets thread's user_id
              trace __FILE__, __LINE__, self, __method__, " : Robe.auth.thread_user_id=#{Robe.auth.thread_user_id}"
              begin
                # trace __FILE__, __LINE__, self, __method__, " calling #{task_name} ->#{block} with #{args}"
                result = args.empty? ? block.call : block.call(**args)
                # trace __FILE__, __LINE__, self, __method__, " : result.class=#{result.class} result=#{result.inspect}"
                result.to_promise.then do |value|
                  # trace __FILE__, __LINE__, self, __method__, " : value = #{value}"
                  value
                end.fail do |result|
                  trace __FILE__, __LINE__, self, __method__, " : #{task_name} failed : result.class=#{value.class} result=#{result}"
                  result
                end
              rescue Robe::TimeoutError => e
                msg = "#{__FILE__}[#{__LINE__}] : task `#{task_name}` timed out after #{@timeout} seconds"
                msg.to_promise_error
              end
            end
          else
            msg = "#{__FILE__}[#{__LINE__}] : invalid server task: #{task_name}"
            trace __FILE__, __LINE__, self, __method__, " : #{msg}"
            msg.to_promise_error
          end
        end

        def send_response(client:, task:, id:, result: nil, error: nil, meta_data: nil)
          # trace __FILE__, __LINE__, self, __method__, " client.id=#{client.id} task=#{task}"
          client.redis_publish(
            channel: task_channel,
            event: :response,
            content: {
              task: task,
              id: id,
              result: result,
              error: error,
              meta_data: meta_data
            }
          )
        end

      end
    end
  end

  module_function

  def task_manager
    @task_manager ||= Robe::Server::Tasks::Manager.instance
  end
end
