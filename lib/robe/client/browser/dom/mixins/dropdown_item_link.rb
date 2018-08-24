# expects to be include'd in a Robe::Client::Browser::DOM::Component
module Robe
  module Client
    module Browser
      module DOM
        module DropdownItemLink

          # Returns a dropdown item (li) wrapping a link
          # Compatible with bootstrap4
          def dropdown_item_link(label, href = nil, &block)
            args = { content: label }
            args[:href] = href
            args[:on] = { click: block } if block
            tag(
              :link,
              css: 'dropdown-item',
              href: href,
              on: { click: block || ->{} }
            )
          end

        end
      end
    end
  end
end