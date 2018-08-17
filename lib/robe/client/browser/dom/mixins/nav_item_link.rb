# expects to be include'd in a Robe::Client::Browser::DOM::Component
module Robe
  module Client
    module Browser
      module DOM
        module NavItemLink

          # Returns a nav list item (li) wrapping a link
          # Compatible with bootstrap4
          def nav_item_link(label, href = nil, &block)
            args = {
              css: 'nav-link',
              content: label
            }
            args[:href] = href if href
            args[:on] = { click: block } if block
            tag(
              :li,
              {
                css: 'nav-item',
                content: tag(:link, args)
              }
            )
          end

        end
      end
    end
  end
end