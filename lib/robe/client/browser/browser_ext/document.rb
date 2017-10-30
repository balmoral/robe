
module Browser
  module DOM
    class Document

      def active_element
        el = `#@native.activeElement()`
        if el
          Browser::DOM::Node.new(el)
        end
      end

    end
  end
end
