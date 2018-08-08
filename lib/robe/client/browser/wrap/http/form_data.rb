module Robe
  module Client
    module Browser
      module Wrap
        module HTTP
          class FormData

            def initialize
              @native = `new FormData()`
            end

            def append(key, value)
              data = if `!!value.native`
                 `value.native`
               else
                 value
               end
              `#@native.append(key, data)`
            end

          end
        end
      end
    end
  end
end
