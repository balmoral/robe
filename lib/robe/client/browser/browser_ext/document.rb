
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

      # not all browsers handle visibility change similarly
      # https://coderwall.com/p/cwpdaw/how-to-tell-if-app-page-has-focus
      # https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API
      # check for document.hidden? to determine whether to render or not
      def on_visibility_change(&block)
        event = if `typeof #{@native}.hidden !== "undefined"`
          'visibilitychange'
        elsif `typeof #{@native}.mozHidden !== "undefined"`
           'mozvisibilitychange'
        elsif `typeof #{@native}.msHidden !== "undefined"`
          'msvisibilitychange'
        elsif `typeof #{@native}.webkitHidden !== "undefined"`
          'webkitvisibilitychange'
        end
        trace __FILE__, __LINE__, self, __method__, " : event=#{event}"
        if event
          on(event) do
            trace __FILE__, __LINE__, self, __method__, " : event=#{event} hidden?=#{hidden?}"
            block.call
          end
        end
      end
      
    end
  end
end
