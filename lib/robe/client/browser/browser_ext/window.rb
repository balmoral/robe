module Browser
  class Window

    @native = `window`

    if `#@native.requestAnimationFrame !== undefined`
      def animation_frame(&block)
        `requestAnimationFrame(block)`
        self
      end
    else
      def animation_frame(&block)
        delay(1.0 / 60, &block)
        self
      end
    end

    def scroll(x, y)
      `window.scrollTo(x, y)`
    end

    alias_method :scroll_to, :scroll

    # opal-browser puts location in a document, we want it in window

    def location
      Location
    end

    # on window 'hashchange' event call given block with
    # window.location.hash as argument
    def on_hash_change(&block)
      listener = lambda { |_event| block.call(location.hash) }
      `window.addEventListener("hashchange", listener, false)`
    end

    module Location
      module_function

      def hash
        `window.location.hash`
      end

      def hash= hash
        `window.location.hash = hash`
      end

      def host
        `window.location.host`
      end

      def hostname
        `window.location.hostname`
      end

      def protocol
        `window.location.protocol`
      end

      def path
        `window.location.pathname`
      end

      def href
        `window.location.href`
      end

      def hash
        `window.location.hash`
      end

      def username
        `window.location.username`
      end

      def password
        `window.location.password`
      end

      def origin
        `window.location.origin`
      end

      def search
        `window.location.search`
      end

      def href=(href)
        `window.location.href = href`
      end

      def reload(force = true)
        `window.location.reload(force)`
      end

      def replace(url)
        `window.location.replace(url)`
      end

      def assign(url)
        `window.location.assign(url)`
      end

    end

=begin
    # use 'opal-browser/history' - must be required somewhere
    module History
      module_function

      def has_push_state?
        `!!window.history.pushState`
      end

      def push path
        `window.history.pushState({}, '', path)`
      end
    end

    def history
      History
    end
=end

  end

  module_function

  def window
    $window # from opal-browser
  end
end
