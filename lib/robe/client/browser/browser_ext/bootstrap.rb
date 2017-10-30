module Browser; module DOM
  class Node

    def check_bootstrap
      %x(
        if (typeof($.fn.tooltip) === 'undefined') {
          throw new Error('Bootstrap.js not loaded');
        }
      )
    end

    # arg may be:
    # 0. nil - attaches tooltip to node
    # 1. hash of options and attaches tooltip to node
    # 2. 'show'
    # 3. 'hide'
    # 4. 'toggle'
    # 4. 'destroy'
    # see http://getbootstrap.com/javascript/#tooltips
    #
    def bootstrap_tooltip(arg=nil)
      check_bootstrap
      arg = {
        title: arg,
        trigger: 'hover focus',
      } if String === arg
      `$(#@native).tooltip(#{arg.to_n})`
    end

    def bootstrap_popover(arg=nil)
      check_bootstrap
      arg = {
        title: arg,
        trigger: 'hover focus',
      } if String === arg
      `$(#@native).popover(#{arg.to_n})`
    end

  end
end end

