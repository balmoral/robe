
module Robe; module Client; module Browser; module Wrap
  module EventTarget
    def on(event_name, &callback)
      wrapper = proc { |event| callback.call Event.new(event) }
      if `#@native.addEventListener !== undefined`
        `#@native.addEventListener(event_name, wrapper)`
      elsif `#@native.addListener !== undefined`
        `#@native.addListener(event_name, wrapper)`
      else
        warn "#{__FILE__}[#{__LINE__}] : #{self} not entirely sure how to add an event listener"
      end
      wrapper
    end

    def off(event_name, &callback)
      if `#@native.removeEventListener !== undefined`
        `#@native.removeEventListener(event_name, callback)`
      elsif `#@native.removeListener !== undefined`
        `#@native.removeListener(event_name, callback)`
      else
        warn "#{__FILE__}[#{__LINE__}] : #{self} not entirely sure how to remove an event listener"
      end

      nil
    end
  end
end end end end
