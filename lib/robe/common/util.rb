require 'robe/common/util/core_ext'

module Robe
  module Util
    module_function

    UUID_VERSION = 4
    UUID_VERSION_HEX = '%02x' % UUID_VERSION

    def on_promise(promise, &block)
      promise.then do |response|
        block.call(response)
      end.fail do |error|
        trace __FILE__, __LINE__, self, __method__, "promise failed => #{error}"
        # app.errors << error
      end
    end

    # Returns a v4 random UUID (Universally Unique Identifier)
    # which is purely random - no time, MAC address implied -
    # expect for the version.
    # e.g. "2d931510-d99f-494a-8c67-87feb05e1594"
    # See RFC 4122 for details of UUID.
    def uuid
      "#{hex_id(4)}-#{hex_id(2)}-#{UUID_VERSION_HEX}#{hex_id(1)}-#{hex_id(2)}-#{hex_id(6)}"
    end

    # Returns a (probably) unique element id
    # composed of hexadecimal digits.
    # The argument `n` specifies the number of 2-character hex values,
    # so the length of the string returned is 2 * n.
    # If `n` is not specified it will default to 16.
    def hex_id(n = 16)
      @@hex_digits ||= ('0'..'9').to_a + ('A'..'F').to_a
      result = ''
      (n * 2).times { result = result + @@hex_digits.sample }
      result
    end

    # args are hashes, lowest to highest precedence,
    # i.e. later args override earlier args
    # goes deep recursively
    def merge_attributes(*args)
      result = args[0] || {}
      args.each do |arg|
        if arg
          arg.each_pair do |key, next_value|
            current_value = result[key]
            if Hash === current_value && Hash === next_value
              result[key] = merge_attributes(current_value, next_value)
            else
              result[key] = next_value
            end
          end
        end
      end
      result
    end

    # nils will not be included
    def arrify(*args)
      result = []
      args.each do |arg|
        if arg
          if Enumerable === arg && !(Hash === arg)
            arg.each do |e|
              result << e unless arg.nil?
            end
          else
            result << arg unless arg.nil?
          end
        end
      end
      result
    end

  end
end

