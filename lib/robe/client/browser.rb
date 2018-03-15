require 'robe/client/browser/browser_ext'
require 'robe/client/browser/websocket'

module Robe
  module Client
    module Browser
      module_function

      def browser
        self
      end
      
      def document
        $document # from opal-browser
      end

      def window
        $window # from opal-browser
      end

      # TODO: should this be here? Only for Volt?
      def dom_root
        unless @dom_root
          if respond_to? :first_element # or container, Volt methods
            self.dom_root = first_element
          else
            # in a separate model?
            fail "#{self.class.name}##{__method__}:#{__LINE_} : dom_root= must be called first"
          end
        end
        @dom_root
      end

      # TODO: should this be here?  Only for Volt?
      def dom_root=(element)
        @dom_root = DOM(element)
      end

      def set_timeout(milliseconds, &callback)
        `setTimeout(callback, milliseconds)`
      end

      alias_method :delay, :set_timeout

      # timeout should be return value #set_timeout or #delay
      def clear_timeout(timeout)
        `clearTimeout(timeout)` if timeout
      end

      def set_interval(milliseconds, &callback)
        `setInterval(callback, milliseconds)`
      end

      alias_method :every, :set_interval

      # interval should be return value #set_interval or #every
      def clear_interval(interval)
        `clearInterval(interval)` if interval
      end

      def cursor(which, &block)
        current = $document.body.style.cursor
        $document.body.style.cursor = which
        if block
          yield
          $document.body.style.cursor = current
        end
      end

      def cursor_wait(&block)
        cursor('wait', &block)
      end

      def cursor_auto(&block)
        cursor('auto', &block)
      end

      def cursor_normal(&block)
        cursor_auto(&block)
      end

      def animate(&block)
        # Browser::AnimationFrame.new(window, &block)
        animation_frame(&block)
      end

    end
  end

  module_function

  def browser
    @browser ||= Robe::Client::Browser
  end

  def window
    browser.window
  end

  def document
    browser.document
  end
end

class Object
  def to_html
    to_s
  end
end

class Numeric
  def px;   "#{self}px"  end
  def em;   "#{self}em"  end
  def rem;  "#{self}rem" end
  def pc;   "#{self}%"   end
  def vh;   "#{self}vh"  end
  def hex;  "#%X" % self end
end
