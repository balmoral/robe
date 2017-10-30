
module Robe; module Client; class Sockets
  class Channel

    attr_reader :name, :socket

    def initialize(name, socket)
      @name = name
      @socket = socket
      @handlers = {}
    end

    def on(event, &block)
      # trace __FILE__, __LINE__, self, __method__, " : event=#{event} block=#{block}"
      (@handlers[event.to_sym] ||= []) << block
    end

    def receive_message(event:, content: nil)
      # trace __FILE__, __LINE__, self, __method__, " : event=#{event} content=#{content.class}"
      if handlers = @handlers[event.to_sym]
        handlers.each do |handler|
          handler.call(content)
        end
      end
    end

    # Close permanently - this instance no longer usable
    def close
      # trace __FILE__, __LINE__, self, __method__, " CLOSE CHANNEL #{name}"
      socket.close_channel(name)
    end

    def open?
      socket.channel?(name)
    end

    def closed?
      !open?
    end

    def send_message(event:,  content: nil)
      # trace __FILE__, __LINE__, self, __method__, " : event=#{event} content=#{content}"
      socket.send_message(channel: name, event: event, content: content)
    end

  end
end end end
