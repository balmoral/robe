
module Robe; module Client; module Browser; module Wrap
  module EventTarget
    def on(event_name, &block)
      wrapper = proc { |event| block.call Event.new(event) }
      if `#@native.addEventListener !== undefined`
        `#@native.addEventListener(event_name, wrapper)`
      elsif `#@native.addListener !== undefined`
        `#@native.addListener(event_name, wrapper)`
      else
        warn "#{__FILE__}[#{__LINE__}] : #{self} not entirely sure how to add an event listener"
      end
      wrapper
    end

    def off(event_name, &block)
      if `#@native.removeEventListener !== undefined`
        `#@native.removeEventListener(event_name, block)`
      elsif `#@native.removeListener !== undefined`
        `#@native.removeListener(event_name, block)`
      else
        warn "#{__FILE__}[#{__LINE__}] : #{self} not entirely sure how to remove an event listener"
      end

      nil
    end
  end
end end end end
