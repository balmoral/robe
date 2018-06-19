require 'browser/dom/document'

module Browser; module DOM
  class Document < Element
    def URL
      `#@native.URL`
    end

    # Returns a ::Browser::DOM::Element.
    def active_element
      el = `#@native.activeElement()`
      Element.new(el) if el
    end

  end
end end