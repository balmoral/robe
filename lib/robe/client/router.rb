require 'browser'
require 'robe/common/trace'
require 'robe/common/redux/stores/model'

# Router is a Redux::Redux::ModelStore which keeps
# the browser location and history in sync
# with the store state.
#
# The app (or owner) should subscribe to router
#   router.subscribe do | route |
#     ...
#     route.path
#     route.params
#   end
#
# or more sensibly bind to the router so that
# when the route changes the page is automatically
# updated:
#
#   bind(router) { |route|
#     case route.parts.first
#       when 'user'
#         Page::User.new(route.params('user'))
#       when 'todos'
#         Page::Todos.new(route.params('todos'))
#       ...
#   }
#
# The state of the store will be the current route
# (a Robe::Client::Route).
#

# REF: https://developer.mozilla.org/en-US/docs/Learn/Common_questions/What_is_a_URL

module Robe; module Client

  class Route < Robe::Model
    attr :path, :params

    def initialize(path)
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
      # trace __FILE__, __LINE__, self, __method__, " : path=#{path} params=#{params}"
      super(path: path, params: params)
    end

    def to_s
      "#{path} #{params}"
    end
  end

  class Router < Robe::Redux::Store

    reduce :route do | path|
      Route.new(path)
    end

    def initialize
      super Route.new(location.path)
      navigate_to('/')
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

    # returns current path (location.path)
    def path
      location.path
    end

    # returns current Route (my state)
    def route
      state
    end

    # called by app following `onpopstate` event (user pressed back or forward)
    def update
      # trace __FILE__, __LINE__, self, __method__, " : location.href=#{location.href} location.path=#{location.path} location.search=#{location.search}"
      dispatch(:route, "#{location.path}#{location.search}")
    end

    def navigate_to(path)
      # trace __FILE__, __LINE__, self, __method__, "(#{path}) : history.push(#{path})"
      history.push(path, {state: 'dummy_state'}, Time.now.to_s) # need this
      # trace __FILE__, __LINE__, self, __method__, "(#{path}) : dispatch(:route, #{path})"
      dispatch(:route, path)
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

  end
end end
