module Robe
  module Client
    module Browser
        class WebSocket
          class CloseEvent
            
            attr_reader :code
            attr_reader :reason

            def initialize(native)
              @native = native
              @code = `#@native.code`
              @reason = `#@native.reason`
              @clean = `#@native.wasClean`
            end

            def to_s
              "#{self.class} : code #{code} : reason #{reason} : clean? #{clean?}"
            end

            def clean?
              !!@clean
            end

          end
        end
    end
  end
end