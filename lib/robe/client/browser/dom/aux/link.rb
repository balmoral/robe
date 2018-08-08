# Link is a replacement for standard dom/html anchors
# to use the Robe::Client::Browser::Router and by-pass
# routing back to the server.

module Robe
  module Client
    module Browser
      module DOM
        class Link < Robe::Client::Browser::DOM::Component

          attr_reader :args

          # a nil href is allowed (for dropdowns, etc)
          def initialize(**args)
            # trace __FILE__, __LINE__, self, __method__, "(#{args})"
            @on_click = (args[:on] || {})[:click]
            href = args[:href]
            if href && href != '#'
              @args = args.merge( on: { click: method(:handle_click) } )
              @args[:key] = href
              check_active(href)
            else
              @args = args
            end
          end

          def href
            args[:href]
          end

          def render
            tag(:a, **args)
          end

          private

          def handle_click(event)
            @on_click.call(event) if @on_click
            if event.prevented?
              warn(
                'You are preventing the default behavior of a `Link` component. ' +
                'In this case, you could just use an `a` element.'
              )
            else
              navigate(event)
            end
          end

          def navigate(event)
            # Don't handle middle-button clicks and clicks with modifier keys. Let them
            # pass through to the browser's default handling or the user's modified handling.
            modified = (
              event.meta? ||
              event.shift? ||
              event.ctrl? ||
              event.alt? ||
              event.button == 1
            )
            unless modified
              event.prevent
              app.router.navigate_to(href)
            end
          end

          def check_active(href)
            if window.location.path == href
              class_name = args.delete(:class).to_s
              args[:class] = "#{class_name} active"
            end
          end

        end
      end
    end
  end
end