
# Conduit to ::Browser::Window
# with some extensions and shortcuts.

module Robe
  module Client
    module Browser
      module Window

        @native = `window`

        module_function

        def to_n
          @native
        end

        if `window.requestAnimationFrame !== undefined`
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

        # Alert the passed string.
        def alert(value)
          `#@native.alert(value)`
          value
        end

        # Display a prompt dialog with the passed string as text.
        def prompt(value)
          `#@native.prompt(value) || nil`
        end

        # Display a confirmation dialog with the passed string as text.
        def confirm(value)
          `#@native.confirm(value) || false`
        end

        # Returns ::Browser::Location
        def location
          $window.location
        end

        def history
          $window.history
        end
        
        def scroll(x, y)
          `#@native.scrollTo(x, y)`
        end

        def on(event, &block)
          $window.on(event, &block)
        end
        
        alias_method :scroll_to, :scroll

        # on window 'hashchange' event call given block with
        # window.location.hash as argument
        def on_hash_change(&block)
          listener = lambda { |_event| block.call(location.hash) }
          `#@native.addEventListener("hashchange", listener, false)`
        end

      end
    end
  end

  module_function

  @window = Robe::Client::Browser::Window

  def window
    @window
  end

end
