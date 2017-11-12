require 'browser'
require 'robe/common/trace'
require 'robe/common/redux/atom'

# Router is a Redux::Redux::Atom which keeps
# the browser location and history in sync
# with the store state.
#
# The app (or owner) should subscribe to router
#   router.observe
#     ...
#     router.path
#     router.params
#   end
#
# or more sensibly bind to the router so that
# when the route changes the page is automatically
# updated:
#
#   bind(router) {
#     case router.path
#       when '/user'
#         Page::User.new(router.params('user'))
#       when '/todos'
#         Page::Todos.new(router.params('todos'))
#       ...
#   }
#

# REF: https://developer.mozilla.org/en-US/docs/Learn/Common_questions/What_is_a_URL

module Robe; module Client
  class Router < Robe::Redux::Atom

    attr :path
    attr :params

    # parses path into path and params
    def self.parse(path)
      # trace __FILE__, __LINE__, self, __method__, " : path=#{path}"
      parts = path.split('/').reject(&:empty?)
      # trace __FILE__, __LINE__, self, __method__, " : parts=#{parts}"
      params = {}
      if parts.size > 1 && parts.last[0] == '?'
        param_s = parts.pop
        param_s = param_s[1..-1]
        param_s.split('&').each do |param|
          key, value = param.split('=')
          params[key] = value if key && value && !key.empty?
        end
      end
      path = '/' + parts.join('/')
      trace __FILE__, __LINE__, self, __method__, " : parts=#{parts} path=#{path} params=#{params}"
      { path: path, params: params}
    end

    def initialize
      super(**parse(location.path))
      trace __FILE__, __LINE__, self, __method__, " self=#{self.to_h}"
      navigate_to('/')
    end

    def to_s
      "#{path}:#{params}"
    end
    def window
      Robe::Client::Browser.window
    end

    def location
      window.location
    end

    def history
      window.history
    end

    # returns current url (location.href)
    def url
      location.href
    end

    # called by app following `onpopstate` event (user pressed back or forward)
    def update
      # trace __FILE__, __LINE__, self, __method__, " : location.href=#{location.href} location.path=#{location.path} location.search=#{location.search}"
      mutate!(**parse("#{location.path}#{location.search}"))
    end

    def navigate_to(path)
      # trace __FILE__, __LINE__, self, __method__, "(#{path}) : history.push(#{path})"
      history.push(path, {state: 'dummy_state'}, Time.now.to_s) # need this
      mutate!(**parse(path))
    end

    alias_method :redirect_to, :navigate_to

    def back
      history.back
      # trace __FILE__, __LINE__, self, __method__, " : #{location.href} #{location.path}"
    end

    def forward
      history.forward
      # trace __FILE__, __LINE__, self, __method__, " : #{location.href} #{location.path}"
    end

    private

    def parse(path)
      self.class.parse(path)
    end
  end
end end
