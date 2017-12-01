
module Browser
  module DOM
    class Document

      def URL
        `#@native.URL`
      end

      def active_element
        el = `#@native.activeElement()`
        if el
          Browser::DOM::Node.new(el)
        end
      end

    end
  end
end
