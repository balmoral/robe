module Robe; module Client; module Browser; module Wrap
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
    
    def delay(duration, &block)
      `setTimeout(block, duration * 1000)`
      self
    end

    def interval(duration, &block)
      `setInterval(block, duration * 1000)`
      self
    end

    alias_method :every, :interval

    def scroll(x, y)
      `window.scrollTo(x, y)`
    end

    def location
      Location.new(`#@native.location`) if `#@native.location`
    end

    def history
      History.new(`#@native.history`) if `#@native.history`
    end
  end

  module_function

  def window
    Wrap::Window
  end
end end end end
