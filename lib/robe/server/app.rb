require 'opal-sprockets'
require 'robe/common/errors'
require 'robe/common/trace'
require 'robe/server/logger'
require 'robe/server/config'
require 'robe/server/rack'
require 'robe/server/tasks'
require 'robe/common/model'
require 'robe/server/db'

# TODO: auth support
# TODO: security/protection/csrf

module Robe; module Server
  class App

    def self.instance
      unless @started
        configure
        trace __FILE__, __LINE__, self, __method__, ' : calling http'
        http
        trace __FILE__, __LINE__, self, __method__, ' : calling sockets'
        sockets
        trace __FILE__, __LINE__, self, __method__, ' : calling db.start'
        db.start if config.use_mongo?
        trace __FILE__, __LINE__, self, __method__
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

    def self.tasks
      Robe.tasks
    end

    def self.db
      Robe.db
    end

    def self.configure
      raise Robe::ConfigError, "#configure method must be implemented in your subclass of #{self.name}"
    end

    # Register a server task.
    #
    # @param [ Symbol ] name Symbol identifying the task.
    # @param [ Boolean ] auth Whether to provide session user cookie to task. Defaults to true.
    # @param [ Lambda ] lambda To perform the task. If nil a block must be given.
    #
    # @yieldparam [ Hash ] Keyword args from client over socket.
    def self.task(name, lambda = nil, auth: true, &block)
      tasks.register(name, lambda, auth: auth, &block)
    end

    task :sign_in do |id:, password:|
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

# TODO: add authentication and sessions per: http://mrcook.uk/simple-roda-blog-tutorial
# TODO: app features (actions, authentication, persistence) as plugins (like Roda)




