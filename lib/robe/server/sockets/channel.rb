require 'set'

# The server has many client socket connections
# on each channel. Keeping track of them here.

module Robe; module Server
  class Sockets
    class Channel

      attr_reader :name, :redis, :redis_channel, :sockets

      def initialize(name, redis, redis_channel)
        @redis = redis
        @redis_channel = redis_channel
        @name = name.to_sym
        @sockets = Set.new
      end

      # called by Sockets::Manager
      def <<(socket)
        sockets << socket
      end

      # called by Sockets::Channels
      def remove_socket(socket)
        sockets.delete(socket)
      end

      def unused?
        sockets.empty?
      end

      # Send a message event and optional contents.
      # Packages message into hash
      #   { channel: name, event: event, content: content }
      # then sends as json via redis.
      def send_message(event:, content: nil)
        message = { channel: name, event: event, content: content }.compact
        json = JSON.generate(message)
        send_json(json)
      end

      # Send an already json'ed string via redis.
      def send_json(json)
        redis.publish(redis_channel, json)
        self
      end

      def on(event, &block)
        Robe.sockets.on(channel: name, event: event, &block)
      end

    end
  end
end end
