require 'opal'
require 'robe/common/trace'
require 'robe/client/router'
require 'robe/client/component'
require 'robe/client/sockets'
require 'robe/client/server'
require 'robe/client/db'
require 'robe/client/browser/data/cookies'
require 'robe/client/app/state'

module Robe
  module_function

  def client?
    true
  end

  def server?
    false
  end

  module Client
    class App
      include Robe::Client::Browser

      attr_reader :state, :router, :component, :root, :on_render, :cookies

      def self.instance
        @@instance
      end

      def self.instance=(instance)
        @@instance = instance
      end

      def self.mount
        instance.mount
      end

      def initialize(component = nil)
        self.class.instance = self
        @state = Robe::Client::App::State.new
        @component = component
        @router = Robe::Client::Router.new(document.URL)
        @on_render = []
        @watching_url = false
        document.on('visibilitychange') do
          if @render_on_visibility_change
            @render_on_visibility_change = false
            render
          end
        end
      end

      %i(user server_errors sign_in_invalid_user sign_in_invalid_password).each do |method|
        define_method(method) { state.send(method) }
        define_method(:"#{method}?") { state.send(:"#{method}?") }
      end

      def user_id
        user? ? user.id : nil
      end

      %i(signed_in? signed_out?).each do |method|
        define_method(method) { state.send(method) }
      end

      # Signs in via User##sign_out.
      # Async operation - return value is meaningless.
      # App state.user is set when sign_in completed
      # or state.sign_in_error is set if error in sign_in.
      # Subclasses should observe(app.state, :user) and
      # observe(app.state, :sign_in_error). If app.state.user?
      # returns false then no user is signed in.
      # An error will be raised if user is not signed out.
      def sign_in(id, password)
        trace __FILE__, __LINE__, self, __method__, "(#{id}, #{password})"
        Robe::Client::App::User.sign_in(id, password)
      end

      # Signs out via User##sign_out.
      # Async operation - return value is meaningless.
      # App state.user is set to nil sign_in completed.
      # Subclasses should observe(app.state, :user).
      # If app.state.user? returns false then no user is signed in.
      # An error will be raised if user is not signed in.
      def sign_out
        raise Robe::UserError, 'there is no current user to sign out' unless user?
        user.sign_out
      end
      
      def server
        @server ||= Robe.server
      end

      def perform_task(name, **kwargs)
        trace __FILE__, __LINE__, self, __method__, "(#{name}, #{kwargs})"
        server.perform_task(name, **kwargs)
      end

      def db
        @db ||= Robe.db
      end

      def mount(&block)
        trace __FILE__, __LINE__, self, __method__
        self.class.instance = self
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
            trace __FILE__, __LINE__, self, __method__, ' : calling router.update'
            router.update
          end
          window.on_hash_change do |new_hash|
            trace __FILE__, __LINE__, self, __method__, " : #{new_hash}"
          end
          @watching_url = true
        end
      end

      def render(&block)
        on_render << block if block
        return if @will_render
        @will_render = true

        # If the app isn't being shown, wait to render until it is.
        trace __FILE__, __LINE__, self, __method__, " : document=#{document.class.name}"
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
        trace __FILE__, __LINE__, self, __method__, " root=#{root}"
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
        trace __FILE__, __LINE__, self, __method__, ' : on_render=#{on_render}'
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
    app_class.instance
  end

end
