
# Conduit to Wrap::Window with some extensions and shortcuts.

module Robe
  module Client
    module Browser
      module Window

        module_function

        def wrap
          @wrap ||= Wrap::Window
        end

        def to_n
          wrap.to_n
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
          `#{to_n}.alert(value)`
          value
        end

        # Display a prompt dialog with the passed string as text.
        def prompt(value)
          `#{to_n}.prompt(value) || nil`
        end

        # Display a confirmation dialog with the passed string as text.
        def confirm(value)
          `#{to_n}.confirm(value) || false`
        end

        # Returns Wrap::Window::Location
        def location
          wrap.location
        end

        def history
          wrap.history
        end

        def scroll(x, y)
          `#{to_n}.scrollTo(x, y)`
        end

        def on(event, &block)
          wrap.on(event, &block)
        end

        alias_method :scroll_to, :scroll

        # on window 'hashchange' event call given block with
        # window.location.hash as argument
        def on_hash_change(&block)
          listener = lambda { |_event| block.call(location.hash) }
          `#{to_n}.addEventListener("hashchange", listener, false)`
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
