module Robe; module Client; module Browser
  class WebSocket
    class CloseEvent
      attr_reader :code, :reason

      def initialize(native)
        @native = native
        @code = `#@native.code`
        @reason = `#@native.reason`
        @clean = `#@native.wasClean`
      end

      def clean?
        !!@clean
      end
    end
  end
end end end