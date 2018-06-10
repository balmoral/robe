require 'opal-sprockets'
require 'robe/common/errors'
require 'robe/common/trace'
require 'robe/server/logger'
require 'robe/server/config'
require 'robe/server/rack'
require 'robe/server/api'
require 'robe/server/task/manager'
require 'robe/server/thread'
require 'robe/server/auth'
require 'robe/common/model'
require 'robe/server/db'

# TODO: auth support
# TODO: security/protection/csrf

module Robe; module Server
  class App

    def self.instance
      unless @started
        ::Thread.abort_on_exception = true
        configure
        # trace __FILE__, __LINE__, self, __method__, ' : calling http'
        http
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
        http.call(env)
      end
    end

    def self.config
      Robe.config
    end

    def self.http
      Robe.http
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
    # @param [ Boolean ] auth Whether to verify user signature in task metadata. Defaults to true.
    # @param [ Lambda ] lambda To perform the task. If nil a block must be given.
    #
    # @yieldparam [ Hash ] Keyword args from client over socket.
    def self.task(name, lambda = nil, auth: true, &block)
      Robe::Server::Api.task(name, lambda, auth: auth, &block)
    end

    # #api is an alias for #task
    def self.api(name, lambda = nil, auth: true, &block)
      Robe::Server::Api.api(name, lambda, auth: auth, &block)
    end

    task :sign_in, auth: false do |id:, password:|
      raise Robe::TaskError, "sign_in task must be implemented in your subclass of #{self.name}"
    end

    # expects user signature
    task :sign_out do |user:|
      raise Robe::TaskError, "sign_in task must be implemented in your subclass of #{self.name}"
    end

  end
end end

# these all add methods to App
require 'robe/server/app/tasks/db'
require 'robe/server/app/state/user'
require 'robe/server/app/state/session'





