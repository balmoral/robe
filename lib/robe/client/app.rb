require 'opal'
require 'robe/common/globals'
require 'robe/common/trace'
require 'robe/client/browser'
require 'robe/client/server/sockets'
require 'robe/client/server'
require 'robe/client/db'
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
      attr_reader :state, :router, :component, :on_rendered, :cookies

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
        @router = Robe::Client::Browser::Router.new(document.URL)
        @on_render = []
        @on_rendered = []
        @watching_url = false
        @render_on_visibility_change = true
        document.on_visibility_change do
          # trace __FILE__, __LINE__, self, __method__, " : document.hidden?=#{document.hidden?} @render_on_visibility_change=#{@render_on_visibility_change}"
          if !document.hidden? && @render_on_visibility_change
            # trace __FILE__, __LINE__, self, __method__
            @render_on_visibility_change = false
            render
          end
        end
      end

      def on_rendered(&block)
        @on_rendered << block
      end

      def dom
        Robe.dom
      end

      def document
        Robe.document
      end

      def window
        Robe.window
      end

      # delegations to user state
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

      def perform_task(name, auth: nil, **args)
        # trace __FILE__, __LINE__, self, __method__, "(name, auth: #{auth}, args: #{args}"
        server.perform_task(name, auth: auth, **args)
      end

      # alias for #perform_task
      def server_api(name, auth: nil, **args)
        perform_task(name, auth: auth, **args)
      end

      def db
        @db ||= Robe.db
      end

      def mount(&block)
        # trace __FILE__, __LINE__, self, __method__
        self.class.instance = self
        render(&block)
        window.on(:resize) { when_resized }
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
          window.on_hash_change do |new_hash|
            # trace __FILE__, __LINE__, self, __method__, " : #{new_hash}"
          end
          @watching_url = true
        end
      end

      def render(&block)
        on_render << block if block
        # trace __FILE__, __LINE__, self, __method__, " : @will_render=#{@will_render}"
        return if @will_render

        # If the app isn't being shown, wait to render until it is.
        # visibilitychanged event is observed in #intialize
        # trace __FILE__, __LINE__, self, __method__, " : document=#{document.class.name} document.hidden?=#{document.hidden?}"
        if document.hidden?
          @render_on_visibility_change = true
          return
        end

        @will_render = true
        window.animation_frame do
          perform_render
          when_rendered
          @on_rendered.each do |block|
            block.call
          end
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

      def body
        @body ||= document.body
      end

      def cookies
        @cookies ||= Robe::Browser::Cookies.new(document)
      end

      def perform_render
        # trace __FILE__, __LINE__, self, __method__
        if body.nil?
          raise TypeError, 'Cannot render to a non-existent document body. Make sure the document ready event has been triggered before invoking the application.'
        end
        component.clear
        body << component.root
        @will_render = false
        run_callbacks
        nil
      end

      def root_element
        body.child
      end

      def run_callbacks
        # trace __FILE__, __LINE__, self, __method__, ' : on_render=#{on_render}'
        @on_render.each(&:render)
        @on_render.clear
      end

      # stub - subclasses may override
      def when_rendered
      end

      # stub - subclasses may override
      def when_resized
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
