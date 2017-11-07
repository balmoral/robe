# https://developer.mozilla.org/en-US/docs/Web/API/Document/cookie
#
# cookies and security
#   ref: https://www.nczonline.net/blog/2009/05/12/cookies-and-security/

require 'robe/client/browser/browser_ext/cookies'
require 'robe/common/redux/atom'

# TODO: Cookies is a mess

module Robe; module Browser
  class Cookies < Robe::Redux::Atom
    include Enumerable

    attr :document, :change, :cookies

    def initialize(document)
      super(
        document: document,
        cookies: ::Browser::Cookies.new(document),
        change: nil
        )
    end

    def user=(user, expiry: Time.now + 60 * 60 * 24)
      self[:user] = user, { expires: expiry, secure: true }
    end

    %i([] keys values each options).each do |method|
      define_method(method) do |*args, &block|
        cookies.send(method, *args, &block)
      end
    end

    %i([]= delete clear).each do |method|
      define_method(method) do |*args, &block|
        cookies = ::Browser::Cookies.new(document)
        cookies.send(method, *args, &block)
        mutate!(cookies: cookies)
      end
    end

  end
end end
