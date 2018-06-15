require 'json'

module Robe; module Client;
  module HTTP
    class Response
      def initialize(xhr)
        @xhr = xhr
      end

      def code
        `#@xhr.status`
      end

      def body
        `#@xhr.response`
      end

      def json
        @json ||= JSON.parse(body) if `#{body} !== undefined`
      end

      def success?
        (200...400).cover?(code)
      end

      def fail?
        !success?
      end
    end
  end
end end
