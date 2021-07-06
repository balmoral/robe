# Adapted from Volt. We don't use drb for now.

require 'singleton'
require 'json'
require 'timeout'     # ruby stdlib

if Robe::Server::USE_CONCURRENT  
  require 'concurrent'  # concurrent-ruby gem
end

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

        def use_basic_threading?
          Robe.config.max_task_threads > 0 && !Robe::Server::USE_CONCURRENT
        end

        def init_threads
          @timeout = Robe.config.task_timeout
          @concurrent_thread_pool = if Robe.config.max_task_threads > 0
            if Robe::Server::USE_CONCURRENT
              Concurrent::CachedThreadPool.new(
                min_threads: [Robe.config.min_task_threads, 1].max,
                max_threads: Robe.config.max_task_threads
              )
            end
          end
        end

        # Dispatch takes an incoming task from the client and runs
        # it on the server, returning the result to the client.
        # Tasks returning a promise will wait to return.
        def process_request(client, request) # , session)
          # trace __FILE__, __LINE__, self, __method__, "(#{client}, #{request})"
          request = request.symbolize_keys
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
          if @concurrent_thread_pool
            @concurrent_thread_pool.post do
              task.call
            end
          elsif use_basic_threading?
            ::Thread.new do
              task.call
            end    
          else
            task.call
          end
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
            logger.failed(name, args, error)
            begin
              # trace __FILE__, __LINE__, self, __method__, "  send_response(task: #{name}, id: #{id}, error: #{error})"
              send_response(client: client, task: name, id: id, error: error)
            rescue JSON::GeneratorError => e
              # trace __FILE__, __LINE__, self, __method__, "  #{e}"
              # Convert the error into a string so it can be serialized to something.
              error = "#{error.class.to_s}: #{error.to_s}"
              logger.failed(name, args, error)
              send_response(client: client, task: name, id: id, error: error)
            end
          end
        end

        # Returns a promise.
        def resolve_task(task_name, args, user)
          # trace __FILE__, __LINE__, self, __method__, " task_name=#{task_name} args=#{args} user=#{user}"
          task = registry[task_name.to_sym]
          # trace __FILE__, __LINE__, self, __method__, " : #{task_name} => #{task}"
          if task
            args = args.dup.symbolize_keys
            block = task[:block]
            if task[:auth]
              error_stub = "Unauthorized #{task_name} request"
              if user.nil? || user.empty?
                msg = "#{error_stub}: missing user data."
                logger.failed(task_name, args, msg)
                return msg.to_promise_error
              end
              user = user.symbolize_keys
              user_id = user[:id]
              if user_id.nil? || user_id.empty?
                msg = "#{error_stub}: missing user id."
                logger.failed(task_name, args, msg)
                return msg.to_promise_error
              end
              user_signature = user[:signature]
              if user_signature.nil? || user_signature.empty?
                msg = "#{error_stub}: missing user signature."
                logger.failed(task_name, args, msg)
                return msg.to_promise_error
              end
              is_valid = Robe.auth.valid_user_signature?(user_id, user_signature)
              unless is_valid
                msg = "#{error_stub}: invalid user signature."
                logger.failed(task_name, args, msg)
                return msg.to_promise_error
              end
            end
            Timeout.timeout(@timeout, Robe::TimeoutError) do
              Robe.auth.thread_user_signature = user_signature if user_signature # this also sets thread's user_id
              begin
                # trace __FILE__, __LINE__, self, __method__, " task_name=#{task_name} args=#{args} user=#{user} : calling block :"
                result = nil
                begin
                  result = args.empty? ? block.call : block.call(**args)
                rescue StandardError => x
                  trace __FILE__, __LINE__, self, __method__, " exception : #{x}"
                  raise x
                end
                result.to_promise.then do |value|
                  value
                end.fail do |result|
                  result
                end
              rescue Robe::TimeoutError => e
                msg = "#{__FILE__}[#{__LINE__}] : task `#{task_name}` timed out after #{@timeout} seconds"
                msg.to_promise_error
              end
            end
          else
            msg = "#{__FILE__}[#{__LINE__}] : invalid server task: #{task_name}"
            logger.failed(task_name, args, msg)
            msg.to_promise_error
          end
        end

        def send_response(client:, task:, id:, result: nil, error: nil, meta_data: nil)
          # trace __FILE__, __LINE__, self, __method__, " client.id=#{client.id} task=#{task}"
          client.publish(
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
