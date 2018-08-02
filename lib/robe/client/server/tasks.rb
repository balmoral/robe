require 'robe/client/server/sockets'
require 'robe/client/util/logger'

module Robe
  module Client
    module Server
      class Tasks

        # Perform the named task on the server with given keyword args.
        # Returns a promise whose value is the task response from the server.
        def self.perform(task_name, auth: nil, **args)
          # trace __FILE__, __LINE__, self, __method__, "(#{task_name}, auth: #{auth}, args: #{args})"
          # Meta data is passed from the browser to the server so the server can know things like who's logged in.
          # We pass meta_data[:user] as hash with user id and user tokenised signature if available.
          send_request(
            task_name,
            user_data(auth: auth),
            args
          )
        end

        def self.user_data(auth: nil)
          user_data = {}
          if auth
            user = Robe.app.user
            raise RuntimeError, "no user available for auth" unless user
            %i(id signature).each do |attr|
              user_data[attr] = user.send(attr)
            end
          end
          user_data
        end

        # private

        # Send request for the named task to be performed on the server
        # # with given meta data and keyword args.
        def self.send_request(task_name, user_data, args)
          # trace __FILE__, __LINE__, self, __method__, "(task: #{task_name}, meta: #{meta_data}, args: #{args})"
          @promises ||= {}
          @task_id ||= 0
          @task_id += 1
          promise = Robe::Promise.new
          @promises[@task_id] = promise
          # TODO: timeout on these callbacks
          # trace __FILE__, __LINE__, self, __method__
          channel.send_message(
            event: :request,
            content: {
              task: task_name,
              args: args,
              id: @task_id,
              user: user_data
            }
          )
          promise
        end

        def self.channel_name
          Robe.sockets.task_channel
        end

        def self.channel
          unless @channel
            @channel = Robe.sockets.open_channel(channel_name)
            @channel.on(:response) do |response|
              # trace __FILE__, __LINE__, self, __method__, " : #{self} on response : response=#{response.class}"
              process_response(response)
            end
          end
          @channel
        end

        # a task response comes as a hash {promise_id:, result:, error:} in json
        def self.process_response(response)
          response = response.symbolize_keys
          # trace __FILE__, __LINE__, self, __method__, " response=#{response.class}"
          task_id = response[:id]
          result = response[:result]
          error = response[:error]
          # cookies = response[:cookies]
          # trace __FILE__, __LINE__, self, __method__, " promise_id=#{promise_id} result=#{result.class} error=#{error}"
          promise = @promises.delete(task_id)
          if promise
            if error
              Robe.logger.error("Task error: #{error}")
              promise.reject(error)
            else
              # trace __FILE__, __LINE__, self, __method__, " response.class=#{response.class} result.class=#{result.class}"
              promise.resolve(result)
            end
          else
            Robe.logger.error("#{__FILE__}[#{__LINE__}] #{self.name}##{__method__} : no promise with id #{task_id} ")
          end
        end

      end
    end
  end

  module_function

  def tasks
    Robe::Client::Server::Tasks
  end
end

