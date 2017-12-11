# Adapted from Volt. We don't use drb for now.

require 'singleton'
require 'json'
require 'timeout'     # ruby stdlib
require 'concurrent'  # concurrent-ruby gem

require 'robe/common/sockets'
require 'robe/server/tasks/logger'
require 'robe/common/promise'
require 'robe/server/config'


# The tasks module takes incoming messages from the
# task socket channel, dispatches them to the
# registered task lambda, and sends responses back
# to the client(s).

module Robe
  module Server
    class Tasks
      include Singleton

      def initialize
        init_sockets
        init_threads
      end

      # Register a server task.
      #
      # @param [ Symbol ] name Symbol identifying the task.
      # @param [ Boolean ] auth Whether to provide session user cookie to task. Defaults to true.
      # @param [ Lambda ] lambda To perform the task. If nil a block must be given.
      #
      # @yieldparam [ Hash ] Keyword args from client over socket.
      def register(name, lambda = nil, auth:, &block)
        unless lambda || block
          raise ArgumentError, 'task requires a lambda or block'
        end
        tasks[name.to_sym] = { lambda: lambda || block, auth: auth }
      end

      private
      
      def tasks
        @tasks ||= {}
      end

      def task_channel
        sockets.task_channel
      end

      def sockets
        Robe.sockets
      end

      def init_sockets
        # trace __FILE__, __LINE__, self, __method__
        sockets.on_channel(task_channel, :request) do |client:, content:|
          process_request(client, content)
        end
      end

      def init_threads
        @thread_pool = Concurrent::CachedThreadPool.new(
          min_threads: Robe.config.min_task_threads,
          max_threads: Robe.config.max_task_threads
        )
        @timeout = Robe.config.task_timeout
      end

      # Dispatch takes an incoming task from the client and runs
      # it on the server, returning the result to the client.
      # Tasks returning a promise will wait to return.
      def process_request(client, request) # , session)
        # trace __FILE__, __LINE__, self, __method__, "(#{request})"
        request = request.symbolize_keys
        # trace __FILE__, __LINE__, self, __method__, "(#{request})"
        # dispatch the task in the thread pool, along with meta data.
        begin
          @thread_pool.post do
            perform_task(
              client: client,
              name: request[:task],
              kwargs: request[:kwargs],
              promise_id: request[:promise_id],
              meta_data: request[:meta_data],
              # session: session
            )
          end
        rescue Exception => e
          msg = "#{__FILE__}[#{__LINE__}] : #{e}"
          Robe.logger.error(msg)
          raise e
        end
      end

      # Perform the task, running inside of a worker thread.
      def perform_task(client:, name:, kwargs:, promise_id:, meta_data:)
        Tasks::Logger.performing(name, kwargs)
        start_time = Time.now.to_f
        resolve_task(name, kwargs, meta_data).then do |result, cookies|
          send_response(client: client, task: name, promise_id: promise_id, result: result, error: nil, cookies: cookies)
          run_time = ((Time.now.to_f - start_time) * 1000).round(3)
          Tasks::Logger.performed(name, run_time, kwargs)
        end.fail do |error|
          begin
            trace __FILE__, __LINE__, self, __method__, "  send_response(task: #{name}, promise_id: #{promise_id}, error: #{error})"
            send_response(task: name, promise_id: promise_id, error: error)
          rescue JSON::GeneratorError => e
            trace __FILE__, __LINE__, self, __method__, "  #{e}"
            # Convert the error into a string so it can be serialized to something.
            error = "#{error.class.to_s}: #{error.to_s}"
            send_response(task: name, promise_id: promise_id, error: error)
          end
        end
      end

      # Returns a promise.
      def resolve_task(task_name, kwargs, meta_data)
        # trace __FILE__, __LINE__, self, __method__, " task_name=#{task_name} kwargs=#{kwargs}"
        task = tasks[task_name.to_sym]
        if task
          lambda = task[:lambda]
          kwargs = kwargs.dup.symbolize_keys
          # TODO:? kwargs[:user]
          # trace __FILE__, __LINE__, self, __method__, " @timeout=#{@timeout}"
          Timeout.timeout(@timeout, Robe::TimeoutError) do
            # trace __FILE__, __LINE__, self, __method__
            Thread.current['meta'] = meta_data
            # trace __FILE__, __LINE__, self, __method__
            begin
              # trace __FILE__, __LINE__, self, __method__, " calling #{task_name} ->#{lambda} with #{kwargs}"
              result = kwargs.empty? ? lambda.call : lambda.call(**kwargs)
              result.to_promise.then do |result|
                # trace __FILE__, __LINE__, self, __method__, " result=#{result.class}"
                cookies = nil # TODO: @task_class.fetch_cookies
                [result, cookies].to_promise
              end
            rescue Robe::TimeoutError => e
              msg = "#{__FILE__}[#{__LINE__}] : task `#{task_name}` timed out after #{@timeout} seconds"
              Robe.logger.error(msg)
              msg.to_promise_error
            ensure
              Thread.current['meta'] = nil
            end
          end
        else
          msg = "#{__FILE__}[#{__LINE__}] : unregistered task: #{task_name}"
          Robe.logger.error(msg)
          msg.to_promise_error
        end
      end

      def send_response(client:, task:, promise_id:, result: nil, error: nil, cookies: nil)
        # trace __FILE__, __LINE__, self, __method__, " client.id=#{client.id} task=#{task}"
        client.redis_publish(
          channel: task_channel,
          event: :response,
          content: {
            task: task,
            promise_id: promise_id,
            result: result,
            error: error,
            cookies: cookies
          }
        )
      end

    end
  end

  module_function

  def tasks
    @tasks ||= Robe::Server::Tasks.instance
  end
end
