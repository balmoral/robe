
module Browser
  module DOM
    class Node

      def as_native
        @native
      end

      # requires jquery and bootstrap.js - will fail otherwise
      def check_jquery
        %x(
          if (typeof jQuery === 'undefined') {
            throw new Error('Bootstrap\'s JavaScript requires jQuery');
          }
        )
      end

      def check_bootstrap
        %x(
          if (typeof($.fn.tooltip) === 'undefined') {
            throw new Error('Bootstrap.js not loaded');
          }
        )
      end

      # TODO: replicate this for all Bootstrap js features
      # TODO: refactor all bootstrap stuff to separate module
      # arg may be:
      # 0. nil - attaches tooltip to node
      # 1. hash of options and attaches tooltip to node
      # 2. 'show'
      # 3. 'hide'
      # 4. 'toggle'
      # 4. 'destroy'
      # see http://getbootstrap.com/javascript/#tooltips
      def tooltip(arg=nil)
        if String === arg
          arg = {
            title: arg,
            trigger: 'hover focus',
          }
        end
        check_bootstrap
        `$(#@native).tooltip(#{arg.to_n})`
      end

      def popover(arg=nil)
        if String === arg
          arg = {
            title: arg,
            trigger: 'hover focus',
          }
        end
        check_bootstrap
        `$(#@native).popover(#{arg.to_n})`
      end

      def replace_child(new_child, old_child)
        parent = as_native
        new_child = new_child.as_native
        old_child = old_child.as_native
        `parent.replaceChild(new_child, old_child)`
        self
      end



    end
  end
end

