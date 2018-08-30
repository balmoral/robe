# expects to be include'd in a Robe::Client::Browser::DOM::Component
module Robe
  module Client
    module Browser
      module DOM
        module NavDropdownItemLink

          # Returns a dropdown item (li) wrapping a link
          # Compatible with bootstrap4
          def nav_dropdown_item_link(label, href = nil, &block)
            args = {
              css: 'dropdown-item nav-link nav-item',
              content: label
            }
            args[:href] = href if href
            args[:on] = { click: block } if block
            tag(:link, **args)
          end

        end
      end
    end
  end
end