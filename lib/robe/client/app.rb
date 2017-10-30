require 'robe/common/trace'
require 'robe/client/router'
require 'robe/client/component'
require 'robe/client/sockets'
require 'robe/client/server'
require 'robe/client/db'
require 'robe/client/browser/data/cookies'

module Robe
  module Client
    class App
      include Robe::Client::Browser

      attr_reader :router, :component, :root, :on_render, :cookies

      def self.current
        @@current
      end

      def self.current=(instance)
        @@current = instance
      end

      def self.mount
        current.mount
      end

      def initialize(component = nil)
        # trace __FILE__, __LINE__, self, __method__, ' '
        @component = component
        @router = Router.new(self)
        @on_render = []
        @watching_url = false
        document.on('visibilitychange') do
          if @render_on_visibility_change
            @render_on_visibility_change = false
            render
          end
        end
      end

      # to be implemented by subclasses
      def user
        nil
      end

      def server
        @server ||= Robe.server
      end

      def perform_task(name, **kwargs)
        server.perform_task(name, **kwargs)
      end

      def db
        @db ||= Robe.db
      end

      def mount(&block)
        # trace __FILE__, __LINE__, self, __method__
        self.class.current = self
        render(&block)
        watch_url
        on_mount
      end
      alias_method :call, :mount

      def on_mount
      end
      
      def watch_url
        # trace __FILE__, __LINE__, self, __method__, " : @watching_url=#{@watching_url}"
        unless @watching_url
          window.on('popstate') do
            # trace __FILE__, __LINE__, self, __method__, ' : calling router.update'
            router.update
          end
          @watching_url = true
        end
      end

      def render(&block)
        on_render << block if block
        return if @will_render
        @will_render = true

        # If the app isn't being shown, wait to render until it is.
        if document.hidden?
          @render_on_visibility_change = true
          return
        end

        window.animation_frame do
          perform_render
        end

        nil
      end

      # Get the first element matching the given ID, CSS selector or XPath.
      #
      # @param what [String] ID, CSS selector or XPath
      #
      # @return [Element?] the first matching element
      def [](what)
        document[what]
      end

      alias_method :element, :[]

      def root
        @root ||= document.body ? document.body : nil
      end

      def cookies
        @cookies ||= Robe::Browser::Cookies.new(document)
      end

      def perform_render
        # puts "#{__FILE__}[#{__LINE__}] : #{self.class.name}##{__method__} : root=#{root} "
        if root.nil?
          raise TypeError, 'Cannot render to a non-existent root element. Make sure the document ready event has been triggered before invoking the application.'
        end
        component.clear
        root << component.root
        @will_render = false
        run_callbacks
        nil
      end

      def root_element
        root.child
      end

      def run_callbacks
        # trace __FILE__, __LINE__, self, __method__, ' : on_render=#{on_render}'
        on_render.each(&:render)
        on_render.clear
      end

    end

  end

  module_function

  def app_class
    @app_class ||= Robe::Client::App
  end

  def app
    app_class.current
  end

end
