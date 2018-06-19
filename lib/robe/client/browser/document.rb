# Conduit to Wrap::Document with some extensions and shortcuts.

module Robe
  module Client
    module Browser
      module Document

        module_function

        def wrap
          @wrap = Wrap.document
        end

        def to_n
          wrap.to_n
        end
        
        def body
          wrap.body
        end

        def hidden?
          wrap.hidden?
        end

        def URL
          wrap.URL
        end

        def create_element(tag, options = {})
          wrap.create_element(tag, options)
        end

        # Returns ::Browser::Location or Bowser::Window::Location
        def location
          wrap.location
        end

        # Returns a ::Browser::DOM::Element or ::Bowser::Element.
        def active_element
          el = `#{to_n}.activeElement()`
          @dom_element_class.new(el) if el
        end

        def [](name)
          wrap[name]
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
          # trace __FILE__, __LINE__, self, __method__, " : event=#{event}"
          if event
            `window.addEventListener(event, block, false)`
          end
        end

      end
    end
  end

  module_function

  @document = Robe::Client::Browser::Document

  def document
    @document
  end
end
