require 'robe/common/trace'
require 'robe/common/sockets'
require 'robe/common/promise'
require 'robe/client/browser'
require 'robe/client/browser/websocket'
require 'robe/client/server/sockets/channel'
require 'robe/client/server/sockets/incoming_message'

module Robe
  module Client
    module Server
      class Sockets
        include Robe::Sockets

        def self.instance(url = nil)
          @instance ||= new(url)
        end

        def initialize(url = nil)
          @url = url
          @channels = {}
          init_socket
        end

        def opened_channel_names
          @channels.keys
        end

        def opened_channels
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
          subscribe_channel(name)
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
              # trace __FILE__, __LINE__, self, __method__, ' : unable to connect to websocket'
              # raise RuntimeError, "#{__FILE__}[#{__LINE__}] : unable to connect to websocket"
            end
            Robe.browser.delay((attempt ** 1.5).to_i) do
              # trace __FILE__, __LINE__, self, __method__, " : not connected : message=#{message} attempt=#{attempt}"
              message[:attempt] = attempt + 1
              send_message(**message)
            end
          end
        end

        private

        def subscribe_channel(name)
          send_message(channel: name, event: :subscribe)
        end

        def init_socket
          # trace __FILE__, __LINE__, self, __method__, " @url='#{@url}'"
          @websocket = Robe::Client::Browser::WebSocket.instance(@url, auto_reconnect: true)
          on_open do |event|
            # if the socket was closed we need to re-subscribe affected channels
            if @resubcribe_channels
              @resubcribe_channels.each do |each|
                subscribe_channel(each.name)
              end
              @resubcribe_channels = nil
            end
          end
          on_close do  |event|
            # if the socket closes we'll need to re-subscribe channels when it's re-opened
            @resubcribe_channels = @channels.values.dup
          end
          on_error do  |event|
            # trace __FILE__, __LINE__, self, __method__, " : error event = #{event}"
          end
          on_message do |message|
            # trace __FILE__, __LINE__, self, __method__, " : message event #{message} : #{message.data}"
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
  end

  module_function

  def sockets
    @sockets ||= Robe::Client::Server::Sockets.instance
  end

end





