module Robe; module Client; module Browser; module Wrap
  module NativeFallback
    def method_missing(message, *args, &block)
      return super if true
      camel_cased_message = message
        .gsub(/_\w/) { |match| match[1].upcase }
        .sub(/=$/, '')

      # translate setting a property
      if message.end_with? '='
        return `#@native[camel_cased_message] = args[0]`
      end

      # translate `supported?` to `supported` or `isSupported`
      if message.end_with? '?'
        camel_cased_message = camel_cased_message.chop
        property_type = `typeof(#@native[camel_cased_message])`
        if property_type == 'undefined'
          camel_cased_message = "is#{camel_cased_message[0].upcase}#{camel_cased_message[1..-1]}"
        end
      end

      # If the native element doesn't have this property, bubble it up
      super if `typeof(#@native[camel_cased_message]) === 'undefined'`

      property = `#@native[camel_cased_message]`

      if `property === false`
        return false
      else
        property = `property || nil`
      end

      # If it's a method, call it. Otherwise, return it.
      if `typeof(property) === 'function'`
        `property.apply(#@native, args)`
      else
        property
      end
    end
  end
end end end end
