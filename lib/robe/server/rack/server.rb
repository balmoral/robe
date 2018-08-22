require 'faye/websocket'

# expects that app gemfile will specify one or other of puma or thin, not both
begin
  require 'puma'
  SERVER = 'puma'
rescue LoadError
  begin
    require 'thin'
    SERVER = 'thin'
  rescue LoadError => x
    Robe.logger.error("Unable to find a compatible rack server. Please ensure your Gemfile includes one of the following: 'thin' or 'puma'")
    raise x
  end
end


module Robe
  module Server
    module Rack
      module Server
        module_function

        def load
          puts "#{__FILE__}[#{__LINE__}] : #{self.name}###{__method__} : SERVER=#{SERVER}"
          Faye::WebSocket.load_adapter(SERVER) if SERVER == 'thin'
        end

      end
    end
  end
end