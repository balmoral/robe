require 'singleton'

module Robe; module Server; class Sockets; end end end

require 'robe/common/sockets'
require 'robe/server/rack/sockets/manager'

module Robe
  module Server
    module Rack
      class Sockets
        include Singleton
        include Robe::Sockets

        REDIS_CHANNEL = :sockets
        REDIS_HEAD_FIELD_LENGTH = 64 # sufficient for channel name or client uuid

        def call(env)
          manager.call(env)
        end

        def on_channel(channel, event, &block)
          manager.on_channel(channel, event, &block)
        end

        def redis_publish(channel:, event:, client: nil, content: nil)
          manager.redis_publish(channel: channel, event: event, client: client, content: content)
        end

        private

        def manager
          @manager ||= Manager.new
        end

      end
    end
  end

  module_function

  def sockets
    @sockets ||= Robe::Server::Rack::Sockets.instance
  end
end


