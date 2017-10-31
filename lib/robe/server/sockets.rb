# inspired by @jgaskins clearwater/power_strip

require 'singleton'
require 'robe/common/sockets'
require 'robe/server/sockets/manager'

module Robe
  module Server
    class Sockets
      include Singleton
      include Robe::Sockets

      # expects roda request
      def route(r)
        r.on 'socket' do
          trace __FILE__, __LINE__, self, __method__, " : r.on 'socket' r=#{r.inspect}"
          r.run manager
        end
      end

      def on(channel:, event:, &block)
        manager.on(channel: channel, event: event, &block)
      end  

      def send_message(channel:, event:, content: nil)
        manager.send_message(channel: channel, event: event, content: content)
      end

      private
      
      def manager
        @manager ||= Manager.new
      end

    end
  end

  module_function

  def sockets
    @sockets ||= Robe::Server::Sockets.instance
  end
end


