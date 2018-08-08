module Robe
  module Client
    module Browser
      class WebSocket
        class IncomingMessage

          def initialize(native_event)
            @native_event = native_event
          end

          def data
            `#@native_event.data`
          end

          def parse
            JSON.parse(data)
          end

        end
      end
    end
  end
end