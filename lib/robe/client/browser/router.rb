require 'robe/common/trace'
require 'robe/common/state/atom'
require 'robe/client/browser/window'

# Router is a State::State::Atom which keeps
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
#       when '/page/user'
#         Page::User.new(router.params('user'))
#       when '/page/todos'
#         Page::Todos.new(router.params('todos'))
#       ...
#   }
#

# REF: https://developer.mozilla.org/en-US/docs/Learn/Common_questions/What_is_a_URL

module Robe
  module Client
    module Browser
      class Router < Robe::State::Atom

        attr :path
        attr :params

        # parses path into path and params
        # where given path has syntax
        # '/page/name?p1=v1&p2=v2'
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
          # trace __FILE__, __LINE__, self, __method__, " : parts=#{parts} path=#{path} params=#{params}"
          { path: path, params: params}
        end

        # Because we're a single page app, when the user hits reload button
        # the current url/location will be sent as a get request to the server.
        # The server can't deal with that, so it responds with a redirect
        # to the root url with a hash which we look out for here. Anything
        # after the # is treated as a the initial path and params for the
        # router.
        def initialize(url = '')
          # trace __FILE__, __LINE__, self, __method__, "url=#{url}"
          hash = url.split('#').last
          args = { path: '/', params: {}}
          if hash
            parts = hash.split('=')
            if parts.first == 'route'
              args = parse(parts.last)
            end
          end
          super(**args)
          # trace __FILE__, __LINE__, self, __method__, " self=#{self.to_h}"
          navigate_to(path)
        end

        def initialize_deprecated
          super(**parse(location.path))
          # trace __FILE__, __LINE__, self, __method__, " self=#{self.to_h}"
          navigate_to('/')
        end

        def to_s
          path_and_params
        end

        def path_and_params
          "#{path}:#{params}"
        end

        def window
          Robe.window
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
          mutate!(**parse("#{location.path}#{location.query}"))
        end

        def navigate_to(path)
          # trace __FILE__, __LINE__, self, __method__, "(#{path}) : history.push(#{path})"
          history.push(path, {state: 'dummy_state'}, Time.now.to_s) # need this
          mutate!(**parse(path))
        end

        def reload_root
          navigate_to('/')
          location.reload(true)
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
    end
  end
end
