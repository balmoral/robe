require 'robe/common/trace'
require 'robe/common/sockets'
require 'robe/common/promise'
require 'robe/client/browser'
require 'robe/client/browser/websocket'
require 'robe/client/sockets/channel'
require 'robe/client/sockets/incoming_message'

module Robe
  module Client
    class Sockets
      include Robe::Sockets

      def self.instance
        @instance ||= new
      end

      def initialize
        @channels = {}
        init_socket
      end

      # TODO: determine ws or wss get from server/document - see Volt for how
      # TODO: allow apps to override or configure ?
      # TODO: in production this should be wss ?
      def url
        unless @url
          # The websocket url can be overridden by config.public.websocket_url
          url = "#{`document.location.host`}/socket"
          if url !~ /^wss?[:]\/\//
            if url !~ /^[:]\/\//
              # Add :// to the front
              url = "://#{url}"
            end
            ws_proto = (`document.location.protocol` == 'https:') ? 'wss' : 'ws'
            # Add wss? to the front
            url = "#{ws_proto}#{url}"
          end
          trace __FILE__, __LINE__, self, __method__, " sockets url = #{url}"
          @url = url
        end
        @url
      end

      def open_channel_names
        @channels.keys
      end

      def open_channels
        @channels.values
      end

      # Returns a Channel with given name if channel is open,
      # or nil if channel is closed or non-existent.
      def [](channel_name)
        @channels[channel_name.to_sym]
      end

      # Returns true if channel with given name is open, else false
      def channel?(name)
        !!@channels[name.to_sym]
      end

      # Returns a Channel with given name.
      def open_channel(name)
        name =  name.to_sym
        channel = @channels[name]
        raise RuntimeError, "channel #{channel} already open" if channel
        channel = Channel.new(name, self)
        @channels[name] = channel
        channel.send_message(event: :subscribe)
        channel
      end

      # Close the channel with the given name.
      def close_channel(name)
        name = name.to_sym
        channel = @channels[name]
        if channel
          channel.send_message(event: :unsubscribe)
          @channels.delete(channel)
        end
      end

      def connected?
        @websocket.connected?
      end

      def on_open(&block)
        @websocket.on(:open, &block)
      end

      def on_close(&block)
        @websocket.on(:close, &block)
      end

      alias_method :on_connect, :on_open
      alias_method :on_disconnect, :on_close

      def on_error(&block)
        @websocket.on(:error, &block)
      end

      def on_message(&block)
        @websocket.on(:message, &block)
      end

      def send_message(channel:, event:, content: nil, attempt: 0)
        message = { channel: channel, event: event, content: content }.compact
        # trace __FILE__, __LINE__, self, __method__, " message = #{message}"
        if connected?
          # trace __FILE__, __LINE__, self, __method__, " : @websocket.send_message(#{message})"
          @websocket.send_message(message)
        else
          if attempt == 20
            trace __FILE__, __LINE__, self, __method__, ' : unable to connect to websocket'
            raise RuntimeError, "#{__FILE__}[#{__LINE__}] : unable to connect to websocket"
          end
          Robe::Client::Browser.delay(attempt * 100) do
            # trace __FILE__, __LINE__, self, __method__, " : not connected : message=#{message} attempt=#{attempt}"
            message[:attempt] = attempt + 1
            send_message(**message)
          end
        end
      end

      private

      def init_socket
        # trace __FILE__, __LINE__, self, __method__, " url='#{url}'"
        @websocket = Robe::Client::Browser::WebSocket.instance(url, auto_reconnect: true)
        # @websocket.auto_reconnect!
        on_open do |event|
          # trace __FILE__, __LINE__, self, __method__, " : open event = #{event}"
        end
        on_close do  |event|
          # trace __FILE__, __LINE__, self, __method__, " : close event = #{event} code=#{event.code} reason=##{event.reason}}"
        end
        on_error do  |event|
          # trace __FILE__, __LINE__, self, __method__, " : error event = #{event}"
        end
        on_message do |message|
          # trace __FILE__, __LINE__, self, __method__, " : message event = #{message}"
          receive_message(message)
        end
      end

      def receive_message(message)
        # trace __FILE__, __LINE__, self, __method__, " : message=#{message.data.class}"
        message = IncomingMessage.new(**message.parse)
        # trace __FILE__, __LINE__, self, __method__, " : channel=#{message.channel} event=#{message.event} content=#{message.content.class}"
        channel = self[message.channel]
        if channel
          channel.receive_message(event: message.event.to_sym, content: message.content)
        end
      end

    end
  end

  module_function

  def sockets
    @sockets ||= Robe::Client::Sockets.instance
  end
end





