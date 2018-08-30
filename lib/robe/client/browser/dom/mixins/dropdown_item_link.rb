# expects to be include'd in a Robe::Client::Browser::DOM::Component
module Robe
  module Client
    module Browser
      module DOM
        module DropdownItemLink

          # Returns a dropdown item (li) wrapping a link
          # Compatible with bootstrap4
          def dropdown_item_link(label, href = nil, &block)
            args = {
              css: 'dropdown-item',
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