# Adapted from Volt. We don't use drb for now.

require 'singleton'
require 'json'
require 'timeout'     # ruby stdlib
require 'concurrent'  # concurrent-ruby gem

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

      # Task name should be symbol identifying the task
      def register(name, lambda = nil, &block)
        unless lambda || block
          raise ArgumentError, 'task requires a lambda or block'
        end
        tasks[name.to_sym] = lambda || block
      end

      private
      
      def tasks
        @tasks ||= {}
      end

      def sockets_channel
        sockets.task_channel
      end

      def sockets
        Robe.sockets
      end

      def init_sockets
        # trace __FILE__, __LINE__, self, __method__
        sockets.on(channel: sockets_channel, event: :request) do |params|
          process_request(params)
        end
      end

      def init_threads
        @thread_pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: Robe.config.min_task_threads,
          max_threads: Robe.config.max_task_threads
        )
        @timeout = Robe.config.task_timeout
      end

      # Dispatch takes an incoming task from the client and runs
      # it on the server, returning the result to the client.
      # Tasks returning a promise will wait to return.
      def process_request(request)
        # trace __FILE__, __LINE__, self, __method__, "(#{request})"
        request = request.symbolize_keys
        # trace __FILE__, __LINE__, self, __method__, "(#{request})"
        # dispatch the task in the thread pool, along with meta data.
        @thread_pool.post do
          # begin
          # trace __FILE__, __LINE__, self, __method__, "(#{request})"
            perform_task(
              name: request[:task],
              kwargs: request[:kwargs],
              promise_id: request[:promise_id],
              meta_data: request[:meta_data]
            )
          # rescue => e
          #   err = "Task thread exception for #{message}\n"
          #  err += e.inspect
          #  err += e.backtrace.join("\n") if e.respond_to?(:backtrace)
          #  trace __FILE__, __LINE__, self, __method__, ' ' + error
          #   Robe.logger.error(err)
          # end
        end
      end

      # Perform the task, running inside of a worker thread.
      def perform_task(name:, kwargs:, promise_id:, meta_data:)
        # trace __FILE__, __LINE__, self, __method__, " : name: #{name} kwargs: #{kwargs} meta_data: #{meta_data} promise_id: #{promise_id}"
        start_time = Time.now.to_f
        resolve_task(name, kwargs, meta_data).then do |result, cookies|
          send_response(task: name, promise_id: promise_id, result: result, error: nil, cookies: cookies)
          run_time = ((Time.now.to_f - start_time) * 1000).round(3)
          Task::Logger.log_perform(name, run_time, kwargs)
        end.fail do |error|
          # begin
            if error.is_a?(Timeout::Error)
              error = Timeout::Error.new("Task timed out after #{@timeout} seconds: #{message}")
            end
            begin
              send_response(task: name, promise_id: promise_id, error: error)
            rescue JSON::GeneratorError => e
              # Convert the error into a string so it can be serialized to something.
              error = "#{error.class.to_s}: #{error.to_s}"
              send_response(task: name, promise_id: promise_id, error: error)
            end
          # rescue => e
          #   Robe.logger.error "Error in fail dispatch: #{e.inspect}"
          #   Robe.logger.error(e.backtrace.join("\n")) if e.respond_to?(:backtrace)
          #   raise
          # end
        end
      end

      # Returns a promise.
      def resolve_task(task_name, kwargs, meta_data)
        # trace __FILE__, __LINE__, self, __method__, " task_name=#{task_name} kwargs=#{kwargs}"
        lambda = tasks[task_name.to_sym]
        if lambda
          kwargs = kwargs.symbolize_keys
          # trace __FILE__, __LINE__, self, __method__, " @timeout=#{@timeout}"
          Timeout.timeout(@timeout) do
            # trace __FILE__, __LINE__, self, __method__
            Thread.current['meta'] = meta_data
            # trace __FILE__, __LINE__, self, __method__
            begin
              # trace __FILE__, __LINE__, self, __method__, " calling #{task_name} ->#{lambda} with #{kwargs}"
              result = kwargs.empty? ? lambda.call : lambda.call(**kwargs)
              # trace __FILE__, __LINE__, self, __method__, " result=#{result.class}"
              cookies = nil # TODO: @task_class.fetch_cookies
              Robe::Promise.value([result, cookies])
            rescue ArgumentError => e
              trace __FILE__, __LINE__, self, __method__, " : #{e}"
              Robe::Promise.error(e.to_s)
            ensure
              Thread.current['meta'] = nil
            end
          end
        else
          msg = "Unregistered task: #{task_name}"
          # trace __FILE__, __LINE__, self, __method__, " error #{msg}"
          Robe::Promise.error(msg)
        end
      end

      def send_response(task:, promise_id:, result: nil, error: nil, cookies: nil)
        sockets.send_message(
          channel: sockets_channel,
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
