require 'robe/client/sockets'

module Robe
  module Client
    module Tasks

      module_function
      
      # Perform the named task on the server with given keyword args.
      # Returns a promise whose value is the task response from the server.
      def perform(task_name, **kwargs)
        # trace __FILE__, __LINE__, self, __method__, "(#{task_name}, {kwargs})"
        # Meta data is passed from the browser to the server so the server can know things like who's logged in.
        # We pass meta_data[:user] as hash with user id and user tokenised signature if available.
        # TODO: consider allowing task to specify required meta data, and caller to be responsible
        meta_data = {}
        if Robe.app.user?
          user = Robe.app.user
          meta_data[:user] = {}
          %i(id signature).each do |attr|
            meta_data[:user][attr] = user.send(attr) if user.respond_to?(attr)
          end
        end
        send_request(task_name, meta_data, **kwargs)
      end

      # private

      # Send request for the named task to be performed on the server
      # # with given meta data and keyword args.
      def self.send_request(task_name, meta_data, **kwargs)
        # trace __FILE__, __LINE__, self, __method__, "(#{task_name}, #{meta_data}, #{kwargs})"
        @promises ||= {}
        @promise_id ||= 0
        promise = Robe::Promise.new
        promise_id = (@promise_id += 1)
        @promises[promise_id] = promise
        # TODO: timeout on these callbacks
        # trace __FILE__, __LINE__, self, __method__
        channel.send_message(
          event: :request,
          content: {
            task: task_name,
            promise_id: promise_id,
            kwargs: kwargs,
            meta_data: meta_data
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
        promise_id = response[:promise_id]
        result = response[:result]
        error = response[:error]
        # cookies = response[:cookies]
        # trace __FILE__, __LINE__, self, __method__, " promise_id=#{promise_id} result=#{result.class} error=#{error}"
        promise = @promises.delete(promise_id)
        if promise
          if error
            Robe.logger.error("Task error: #{error}")
            promise.reject(error)
          else
            # trace __FILE__, __LINE__, self, __method__, " response.class=#{response.class} result.class=#{result.class}"
            promise.resolve(result)
          end
        else
          Robe.logger.error("#{__FILE__}[#{__LINE__}] #{self.name}##{__method__} : no promise with id #{promise_id} ")
        end
      end

    end
  end

  module_function

  def tasks
    Robe::Client::Tasks
  end
end

