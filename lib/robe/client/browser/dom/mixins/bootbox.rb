require 'opal'
# see http://bootboxjs.com/documentation.html

# NB: you need to bring your own `bootbox.js` or `bootbox.min.js` and bootstrap files

module Robe
  module Client
    module Browser
      module DOM
        module Bootbox
          module_function

          def bootbox_call(method, *args, &block)
            arg = args.first
            if arg.is_a?(Hash) && arg[:callback].nil?
              arg[:callback] = block
              Native.call(`bootbox`, method, arg.to_n)
            else
              Native.call(`bootbox`, method, arg.to_n, &block)
            end
          end

          # Creates an alert window.
          # The given block is optional.
          # Method executes asynchronously.
          # No result is passed to the given block.
          def alert(*args, &block)
            bootbox_call(__method__, *args, &block)
          end

          # Creates a confirm window.
          # Method executes asynchronously.
          # The result passed to given block is true or false.
          def confirm(*args, &block)
            `console.log(#{"#{__FILE__}[#{__LINE__}]:#{self.class.name}##{__method__}"})`
            bootbox_call(__method__, *args, &block)
          end

          # Creates a prompt window.
          # Method executes asynchronously.
          # The result passed to given block is a String or nil.
          def prompt(*args, &block)
            bootbox_call(__method__, *args, &block)
          end

          # Creates a custom dialog window.
          # Method executes asynchronously.
          # The result passed to given block is a String or nil.
          # see http://bootboxjs.com/examples.html
          def dialog(*args, &block)
            bootbox_call(__method__, *args, &block)
          end

        end
      end
    end
  end
end


