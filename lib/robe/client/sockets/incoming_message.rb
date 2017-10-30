module Robe; module Client
  class Sockets
    class IncomingMessage

      attr_reader :channel, :event, :content

      def initialize(channel:, event:, content: nil)
        @channel, @event, @content = channel, event, content
      end

      def to_h
        {
          channel: channel,
          event: event,
          content: content
        }
      end

    end
  end
end end