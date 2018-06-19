
require 'robe/client/browser/wrap'
require 'robe/client/browser/window'
require 'robe/client/browser/document'
require 'robe/client/browser/websocket'
require 'robe/client/browser/data'
require 'robe/client/browser/dom'
require 'robe/client/browser/router'

module Robe
  module Client
    module Browser
      module_function

      def document
        @document ||= Robe::Client::Browser::Document
      end

      def window
        @window ||= Robe::Client::Browser::Window
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
        current = document.body.style.cursor
        $document.body.style.cursor = which
        if block
          yield
          document.body.style.cursor = current
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

