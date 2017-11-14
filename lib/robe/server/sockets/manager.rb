require 'set'
require 'json'
require 'faye/websocket'
require 'robe/server/redis'
require 'robe/server/sockets/channels'

module Robe; module Server
  class Sockets
    class Manager

      attr_reader :redis, :redis_channel, :channels

      def initialize
        @redis = Robe.redis
        @redis_channel = :sockets
        @channels = Channels.new(redis, redis_channel)
        @handlers = {} # callbacks
        @subscriptions = Set.new
        Thread.new { monitor_redis }
      end

      def on(channel:, event:, &block)
        ((@handlers[channel.to_sym] ||= {})[event.to_sym] ||= []) << block
      end

      def send_message(channel:, event:, content: nil)
        @channels[channel].send_message(event: event, content: content)
      end


      # This is the main socket connection and message handler.
      #
      # Incoming messages are expected to be hashes in JSON format with
      # channel:, event: and content:.
      #
      # NB channels can be associated with multiple (client) socket connections.
      #
      def call(env)
        # trace __FILE__, __LINE__, self, __method__
        if Faye::WebSocket.websocket?(env)
          # trace __FILE__, __LINE__, self, __method__, "env=#{env}"
          protocols = nil
          options = { ping: 1 } # keep socket alive : Chrome seems to time out in about 10?
          socket = Faye::WebSocket.new(env, protocols, options)
          connect!(socket)
          # trace __FILE__, __LINE__, self, __method__
          response = socket.rack_response
          # trace __FILE__, __LINE__, self, __method__, " response = #{response}"
          response
        else
          # trace __FILE__, __LINE__, self, __method__, ' : BAD WEB SOCKET REQUEST !!'
          response_to_invalid_request
        end
      end

      private

      def connect!(socket)
        socket.on(:open) do
          trace __FILE__, __LINE__, self, __method__, " : open event"
        end
        socket.on(:close) do |event|
          trace __FILE__, __LINE__, self, __method__, " : close event code=#{event.code} reason=#{event.reason}"
          @subscriptions.each do |channel|
            channels.close(channel: channel, socket: socket)
          end
        end
        socket.on(:message) do |ws_message_event|
          # trace __FILE__, __LINE__, self, __method__, " : message event : #{ws_message_event}"
          process_message(socket, ws_message_event.data)
        end
      end

      def process_message(socket, json)
        # trace __FILE__, __LINE__, self, __method__, " : message json=#{json}"
        begin
          message = JSON.parse(json).symbolize_keys
          channel_name = message[:channel].to_sym
          event = message[:event].to_sym
          content = message[:content]
          channel = channels[channel_name]
          # trace __FILE__, __LINE__, self, __method__, " : message=#{message}"
          case event
            when :subscribe
              trace __FILE__, __LINE__, self, __method__, " : subscribe"
              channel << socket
              @subscriptions << channel
              ack = JSON.generate({ channel: channel_name, event: :subscribed })
              socket.send(ack)
            when :unsubscribe
              trace __FILE__, __LINE__, self, __method__, " : unsubscribe"
              @subscriptions.delete(channel)
              channel.delete(socket)
              ack = JSON.generate({ channel: channel_name, event: :unsubscribed })
              socket.send(ack)
            else
              # trace __FILE__, __LINE__, self, __method__
              resolved_handlers(channel_name, event).each do |callback|
                # begin
                  callback.call(content)
                # rescue => e
                #      warn "[#{self.class.name}] #{e.inspect}"
                # end
              end
          end
        rescue ::JSON::ParserError
          trace __FILE__, __LINE__, self, __method__, " : invalid JSON : "
          # Ignore invalid JSON
        end
      end

      # Subscribe to any messages sent via redis
      # from our channels, and resend them over
      # the channel's socket.
      def monitor_redis
        redis.dup.subscribe(redis_channel) do |on|
          on.message do |_, message|
            channel = JSON.parse(message)['channel']
            channels[channel].sockets.each do |socket|
              socket.send(message)
            end
          end
        end
      end

      # Returns any handlers found for a channel and event.
      def resolved_handlers(channel_name, event)
        (@handlers[channel_name.to_sym] || {})[event.to_sym] || []
      end


      def response_to_invalid_request
        [
          400,
          { 'Content-Type' => 'text/plain' },
          ['This endpoint only handles websockets'],
        ]
      end

    end
  end
end end
