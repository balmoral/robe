require 'json'
require 'faye/websocket'
require 'robe/common/util'
require 'robe/server/redis'
require 'robe/server/rack/sockets/client'

# TODO: implement redis to store socket/client lookup for lots of clients

module Robe
  module Server
    module Rack
      class Sockets
        class Manager

          def initialize
            @handlers = {}    # server-side channel+event handler callbacks
            @clients = {}     # client id => a Client
            @sockets = {}     # socket object id => a Client
            @subscribers = {} # channel name => a Hash of client_id => Client
            Thread.new { monitor_redis }
          end

          def redis
            Robe.redis
          end

          def on_channel(channel, event, &block)
            ((@handlers[channel.to_sym] ||= {})[event.to_sym] ||= []) << block
          end

          # This is the main socket connection and message handler.
          #
          # Incoming messages are expected to be hashes in JSON format with
          # channel:, event: and content:.
          #
          # NB channels can be associated with multiple (client) socket connections.
          #
          # Assumes caller has confirmed websocket?(env).
          def call(env)
            # trace __FILE__, __LINE__, self, __method__, "env=#{env}"
            protocols = nil
            options = { ping: 5 } # keep socket alive : Chrome seems to time out in about 10?
            socket = Faye::WebSocket.new(env, protocols, options)
            connect!(socket)
            # trace __FILE__, __LINE__, self, __method__
            socket.rack_response
          end

          # Publish a message event and optional contents on redis
          # to one or all clients on the given channel.
          #
          # A JSON message is constructed from a hash containing:
          #
          #   { channel: name, event: event, content: content }
          #
          # The message is sent via redis, prefixed with
          # channel and client identification for the socket
          # manager's use.
          #
          # If the client is nil then all client sockets will be sent the message.
          # If the client is given then only that client will be sent the message.
          #
          def redis_publish(channel:, event:, client: nil, content: nil)
            # trace __FILE__, __LINE__, self, __method__, " channel=#{channel} event=#{event} client.id=#{client ? client.id : ''} content=#{content.class}"
            json = { channel: channel, event: event, content: content }.compact
            channel_tag = channel.to_s.ljust(REDIS_HEAD_FIELD_LENGTH)
            client_tag = (client ? client.id : '').ljust(REDIS_HEAD_FIELD_LENGTH)
            json = JSON.generate(json)
            message = channel_tag + client_tag + json
            # trace __FILE__, __LINE__, self, __method__, " : #{message[0,80]}"
            redis.publish(REDIS_CHANNEL, message)
          end

          private

          def connect!(socket)
            add_client(socket)
            socket.on(:open) do
              client_event(socket, :open) do |_client|
                # nothing
              end
            end
            socket.on(:close) do |event|
              client_event(socket, :close, event) do |client|
                remove_client(client)
              end
            end
            socket.on(:message) do |event|
              client_event(socket, :message, event) do |client|
                process_message(client, event.data)
              end
            end
          end

          def client_event(socket, event_name, event = nil, &block)
            client = @sockets[socket]
            # trace __FILE__, __LINE__, self, __method__, " : #{event_name} : event.code=#{event_name == :close ? event.code : 'n/a'} : client=#{client} "
            if client
              block.call(client)
            else
              Robe.logger.error("> > > > > #{__method__}(#{event_name}) : no client associated with socket #{socket.object_id} < < < < <")
            end
          end

          def add_client(socket)
            client = Client.new(socket)
            @sockets[client.socket] = client
            @clients[client.id] = client
          end

          def remove_client(client)
            @sockets.delete(client.socket)
            @clients.delete(client.id)
            client.channels do |channel|
              channel_subscribers(channel).delete(client.id)
            end
          end

          def process_message(client, json)
            # trace __FILE__, __LINE__, self, __method__, " : client=#{client} json=#{json[0,60]}"
            begin
              message = JSON.parse(json).symbolize_keys
              channel = message[:channel].to_sym
              event = message[:event].to_sym
              case event
                when :subscribe
                  subscribe_client(client, channel)
                when :unsubscribe
                  unsubscribe_client(client, channel)
                else
                  handle_message(channel, event, client, message[:content])
              end
            rescue ::JSON::ParserError
              # ignore invalid JSON, but log it
              Robe.logger.error("invalid JSON received on channel #{channel} for event #{event}")
            end
          end

          def handle_message(channel, event, client, content)
            # trace __FILE__, __LINE__, self, __method__, " : client.id=#{client.id} channel=#{channel} event=#{event}"
            channel_handlers(channel, event).each do |handler|
              handler.call(client: client, content: content)
            end
          end

          def subscribe_client(client, channel)
            # trace __FILE__, __LINE__, self, __method__, " : subscribe client.id=#{client.id} channel=#{channel}"
            channel_subscribers(channel)[client.id] = client
            client.channels << channel
            client.redis_publish(channel: channel, event: :subscribed)
          end

          def unsubscribe_client(client, channel)
            # trace __FILE__, __LINE__, self, __method__, " : unsubscribe client.id=#{client.id} channel=#{channel}"
            channel_subscribers(channel).delete(client.id)
            client.channels.delete(channel)
            client.redis_publish(channel: channel, event: :unsubscribed)
          end

          def channel_subscribers(channel)
            @subscribers[channel] ||= {}
          end

          # Returns any handlers found for a channel and event.
          def channel_handlers(channel, event)
            (@handlers[channel.to_sym] || {})[event.to_sym] || []
          end

          # Subscribe to any messages sent via redis from our channels, and resend them over socket(s).
          # Any socket message via redis will have three parts:
          # 1. channel name : REDIS_HEAD_FIELD_LENGTH chars padded with spaces
          # 2. client id : REDIS_HEAD_FIELD_LENGTH chars padded with spaces
          # 3. the JSON message to be sent over the socket
          # If the client id when stripped is empty then all client sockets will be sent the message.
          # If the client id when stripped is specified then only that client will be sent the message.
          # NB: the JSON message should also include the channel name for the actual client's use.
          # It is up to the socket handlers to determine how they are broadcasting.
          def monitor_redis
            redis.dup.subscribe(REDIS_CHANNEL) do |on|
              on.message do |_, message|
                l = REDIS_HEAD_FIELD_LENGTH
                channel = message[0, l].strip
                client_id = message[l, l].strip
                json = message[(l * 2)..-1]
                # trace __FILE__, __LINE__, self, __method__, " : client_id=#{client_id} channel=#{channel} json=#{json[0,64]}"
                if channel.empty?
                  raise RuntimeError, 'missing channel name in redis socket packet'
                end
                if client_id.empty?
                  channel_subscribers(channel).values.each do |client|
                    client.socket_send(json)
                  end
                else
                  client = @clients[client_id]
                  if client
                    client.socket_send(json)
                  else
                    Robe.logger.error("#{__FILE__}[##{__LINE__}] : #{self.class}##{__method__} : unregistered client id #{client_id}")
                  end
                end
              end
            end
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
    end
  end
end
