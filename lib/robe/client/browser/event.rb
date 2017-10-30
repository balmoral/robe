require 'robe/common/trace'
# mostly cloned from clearwater-bowser - thanks to Jamie Gaskins (@jgaskins)
# TODO: move to opal-browser

# change event: https://developer.mozilla.org/en-US/docs/Web/Events/change

module Robe; module Client; module Browser
  class Event
    def initialize(native)
      @native = native
    end

    def prevent
      `#@native.preventDefault()`
      self
    end

    def stop_propagation
      `#@native.stopPropagation()`
      self
    end

    def prevented?
      `#@native.defaultPrevented`
    end

    def meta?
      `#@native.metaKey`
    end

    def shift?
      `#@native.shiftKey`
    end

    def ctrl?
      `#@native.ctrlKey`
    end

    def alt?
      `#@native.altKey`
    end

    def target
      # Element.new(`#@native.currentTarget`)
      Element.new(`#@native.target`)
    end

    def code
      `#@native.keyCode`
    end

    def method_missing(name, *args)
      property = name.gsub(/_[a-z]/) { |match| match[-1, 1].upcase }
      value = `#@native[property]`

      if `!!value && #{Proc === value}`
        value.call(*args)
      elsif `value == null`
        nil
      else
        value
      end
    end

    def to_n
      @native
    end
  end

end end end
