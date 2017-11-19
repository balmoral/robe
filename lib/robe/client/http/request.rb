require 'json'
require 'robe/client/http/response'
require 'robe/client/browser/event_target'

module Robe; module Client
  module HTTP
    class Request
      include Robe::Client::Browser::EventTarget

      attr_reader :method, :url, :data, :headers
      attr_accessor :response

      UNSENT           = 0
      OPENED           = 1
      HEADERS_RECEIVED = 2
      LOADING          = 3
      DONE             = 4

      def initialize(method, url, native: `new XMLHttpRequest()`)
        @native = native
        @method = method
        @url = url
        @response = Response.new(@native)
      end

      def send(data: {}, headers: {})
        `#@native.open(#{method}, #{url})`
        @data = data
        self.headers = headers

        if method == :get || method == :delete
          `#@native.send()`
        elsif data.is_a?(Hash)
          `#@native.send(#{JSON.generate data})`
        elsif `!!data.native`
          `#@native.send(data.native)`
        else
          `#@native.send(data)`
        end

        self
      end

      def headers= headers
        @headers = headers
        headers.each do |attr, value|
          `#@native.setRequestHeader(attr, value)`
        end
      end

      def post?
        method == :post
      end

      def get?
        method == :get
      end

      def ready_state
        `#@native.readyState`
      end

      def sent?
        ready_state >= OPENED
      end

      def headers_received?
        ready_state >= HEADERS_RECEIVED
      end

      def loading?
        ready_state == LOADING
      end

      def done?
        ready_state >= DONE
      end
    end
  end
end end
