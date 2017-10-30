require 'robe/server/sockets/channel'

module Robe; module Server
  class Sockets
    class Channels

      attr_reader :redis, :redis_channel

      def initialize(redis, redis_channel)
        @redis = redis
        @redis_channel = redis_channel
        @channels = {}
      end

      def [](name)
        name = name.to_sym
        @channels[name] ||= Channel.new(name, redis, redis_channel)
      end

      def close(channel:, socket:)
        channel.remove_socket(socket)
        @channels.delete(channel.name) if channel.unused?
      end

    end
  end
end end
