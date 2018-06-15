# expects to be include'd in a Robe::Client::Browser::DOM::Component
module Robe; module Client; module Browser; module DOM

  module ListItemLink

    # returns a list item (li) wrapping a link
    def list_item_link(label, href = nil, &block)
      args = [:link, { content: label }]
      args.last.merge!(href: href) if href
      args.last.merge!(on: { click: block }) if block
      tag(:li, tag(*args))
    end

  end

end end end end