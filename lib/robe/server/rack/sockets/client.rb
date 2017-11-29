require 'set'
require 'robe/common/model'

# TODO: implement redis to store socket/client lookup for lots of clients

module Robe::Server
  class Sockets

    class Client < Robe::Immutable
      attr :id
      attr :socket
      attr :channels

      def initialize(socket)
        super(id: Robe::Util.uuid, socket: socket, channels: Set.new)
      end

      def ==(other)
        id == other.id
      end

      def eql?(other)
        id == other.id
      end

      def hash
        id
      end

      def redis_publish(channel:, event:, content: nil)
        unless channels.include?(channel)
          raise RuntimeError, "#{self.class.name}##{__method__} : client not subscribed to channel #{channel}"
        end
        Robe.sockets.redis_publish(channel: channel, event: event, client: self, content: content)
      end

      def socket_send(message)
        socket.send(message)
      end

      def to_s
        "#{id}:#{channels.to_a}"
      end
    end

  end
end
