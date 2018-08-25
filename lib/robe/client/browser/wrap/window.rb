module Robe
  module Client
    module Browser
      module Wrap
        module Window
          extend EventTarget

          @native = `window`

          module_function

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

          def to_n
            @native
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

          def scroll(x, y)
            `#{to_n}.scrollTo(x, y)`
          end

          alias_method :scroll_to, :scroll

          def delay(duration, &block)
            `setTimeout(block, duration * 1000)`
            self
          end

          def interval(duration, &block)
            `setInterval(block, duration * 1000)`
            self
          end

          alias_method :every, :interval

          def location
            Location.new(`#@native.location`) if `#@native.location`
          end

          def history
            History.new(`#@native.history`) if `#@native.history`
          end

          # on window 'hashchange' event call given block with
          # window.location.hash as argument
          def on_hash_change(&block)
            listener = lambda { |_event| block.call(location.hash) }
            `#{to_n}.addEventListener("hashchange", listener, false)`
          end

        end
      end
    end
  end
end
