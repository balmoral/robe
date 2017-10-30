# https://developer.mozilla.org/en-US/docs/Web/API/Document/cookie
#
# cookies and security
#   ref: https://www.nczonline.net/blog/2009/05/12/cookies-and-security/

require 'robe/client/browser/browser_ext/cookies'
require 'robe/common/model'
require 'robe/common/redux/stores/model'

# TODO: Cookies is a mess

module Robe; module Browser
  class Cookies < Robe::Redux::ModelStore
    include Enumerable

    class State < Robe::Model
      include Enumerable

      attr :document, :change

      def self.read_methods
        [:[], :keys, :values, :each, :options]
      end

      def self.write_methods
        [:[]=, :delete, :clear]
      end

      def initialize(document, change = nil)
        super(document: document, change: change)
        @cookies = ::Browser::Cookies.new(document)
      end

      (read_methods + write_methods).each do |method|
        define_method(method) do |*args, &block|
          @cookies.send(method, *args, &block)
        end
      end

      def cookies
        @cookies
      end

    end

    model State

    def initialize(document)
      super State.new(document: document)
      # state.cookies.on_change method(:on_change)
    end

    def user=(user, expiry: Time.now + 60 * 60 * 24)
      self[:user] = user, { expires: expiry, secure: true }
    end

    def on_change(**args)
      dispatch(:change, args)
    end

  end
end end
