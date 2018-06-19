# https://developer.mozilla.org/en-US/docs/Web/API/Document/cookie
#
# cookies and security
#   ref: https://www.nczonline.net/blog/2009/05/12/cookies-and-security/

require 'robe/common/state/atom'

# TODO: Cookies is a mess - clean it up and finish it

module Robe; module Browser
  class Cookies < Robe::State::Atom
    include Enumerable

    attr :document, :change, :cookies

    def initialize(document)
      super(
        document: document,
        cookies: wrap(document),
        change: nil
        )
    end

    %i([] keys values each options).each do |method|
      define_method(method) do |*args, &block|
        cookies.send(method, *args, &block)
      end
    end

    %i([]= delete clear).each do |method|
      define_method(method) do |*args, &block|
        cookies = wrap(document)
        cookies.send(method, *args, &block)
        mutate!(cookies: cookies)
      end
    end

    private

    def wrap(document)
      Robe::Client::Browser::Wrap::Cookies.new(document)
    end
  end
end end
