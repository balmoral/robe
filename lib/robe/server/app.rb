require 'robe/common/globals'
require 'robe/common/errors'
require 'robe/common/trace'
require 'robe/server/util/logger'
require 'robe/server/config'
require 'robe/server/rack'
require 'robe/server/sockets'
require 'robe/server/task'
require 'robe/server/thread'
require 'robe/server/auth'
require 'robe/common/model'
require 'robe/server/db'
require 'robe/server/app/builder'

# TODO: auth support
# TODO: security/protection/csrf

module Robe
  module Server
    class App

      def self.build
        configure
        Robe::Server::App::Builder.build
      end

      # Returns self.
      # Initializes rack, assets, sockets, task manager and database.
      def self.instance
        # ::Thread.abort_on_exception = true
        unless @started
          configure
          # trace __FILE__, __LINE__, self, __method__, ' : calling rack_app'
          rack_app
          # trace __FILE__, __LINE__, self, __method__, ' : calling sockets'
          sockets
          # trace __FILE__, __LINE__, self, __method__, ' : calling task_manager'
          task_manager
          # trace __FILE__, __LINE__, self, __method__, ' : calling db.start'
          db.start if config.use_mongo?
          # trace __FILE__, __LINE__, self, __method__
          @started = true
        end
        self
      end

      def self.call(env)
        # req = Rack::Request.new(env)
        # trace __FILE__, __LINE__, self, __method__, " : req.cookies=#{req.cookies}"
        if Faye::WebSocket.websocket?(env)
          sockets.call(env)
        else
          rack_app.call(env)
        end
      end

      def self.config
        Robe.config
      end

      def self.rack_app
        Robe.rack_app
      end

      def self.sockets
        Robe.sockets
      end

      def self.task_manager
        Robe.task_manager
      end

      def self.db
        Robe.db
      end

      def self.thread
        Robe.thread
      end

      def self.auth
        Robe.auth
      end

      def self.configure
        raise Robe::ConfigError, "#configure method must be implemented in your subclass of #{self.name}"
      end

      # Register a server task.
      #
      # @param [ Symbol ] name Symbol identifying the task.
      # @param [ Boolean ] auth Whether to verify user signature in task metadata. Defaults to true. Block should expect user_id: argument if auth is true.
      #
      # @yieldparam [ Hash ] Keyword args from client over socket.
      def self.task(name, auth: true, &block)
        Robe::Server::Task.task(name, auth: auth, &block)
      end

      # #api is an alias for #task
      def self.api(name, auth: true, &block)
        task(name, auth: auth, &block)
      end

      task :sign_in, auth: false do |_id:, _password:|
        raise Robe::TaskError, "sign_in task must be implemented in your subclass of #{self.name}"
      end

      # expects user signature
      task :sign_out, auth: true do |_user:|
        raise Robe::TaskError, "sign_in task must be implemented in your subclass of #{self.name}"
      end

    end
  end
end

# these all add methods to App
require 'robe/server/app/tasks/db'
require 'robe/server/app/state/user'
require 'robe/server/app/state/session'





