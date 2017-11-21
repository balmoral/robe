require 'roda'
require 'robe/common/errors'
require 'robe/common/trace'
require 'robe/server/logger'
require 'robe/server/config'
require 'robe/server/assets'
require 'robe/server/sockets'
require 'robe/server/tasks'
require 'robe/common/model'
require 'robe/server/db'

# ref: http://mrcook.uk/simple-roda-blog-tutorial
# ref: http://mrcook.uk/static-websites-with-roda-framework
# require 'bcrypt'
# require 'rack/protection'
# roda ref: http://roda.jeremyevans.net/rdoc/files/README_rdoc.html

# TODO: auth support
# TODO: https://github.com/jeremyevans/rodauth

module Robe; module Server
  class App < ::Roda

    def self.start
      trace __FILE__, __LINE__, self, __method__, 'calling db.start'
      db.start if config.use_mongo?
    end
    
    def self.config
      Robe.config
    end

    def self.assets
      Robe.assets
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
      raise Robe::TaskError, "sign_in task needs to be implemented in your subclass of #{self.name}"
    end

    # expects user signature
    task :sign_out do |user:|
      raise Robe::TaskError, "sign_in task needs to be implemented in your subclass of #{self.name}"
    end

    # for r.session[:...]
    use Rack::Session::Cookie, secret: config.app_secret

    # :head - treat HEAD requests like GET requests with an empty response body
    plugin :head

    # :json - Allows match blocks to return arrays and hashes, using a json representation as the response body.
    plugin :json, classes: [Array, Hash, Robe::Model]

    # cross site request forgery protection, exempt json ??
    plugin :csrf, skip_if: ->(req){req.env['CONTENT_TYPE'] =~ /application\/json/}


    # we expect only asset or socket requests
    route do |r|
      sockets.route(r) # sockets first
      assets.route(r)
    end

    # FYI called for every router request
    def initialize(*args, &block)
      # trace __FILE__, __LINE__, self, __method__, " ************************************ "
      super
    end

    def assets
      self.class.assets
    end

    def sockets
      self.class.sockets
    end

    def db
      self.class.db
    end

  end
end end

# these all add methods to App
require 'robe/server/app/tasks/db'
require 'robe/server/app/state/user'
require 'robe/server/app/state/session'

# TODO: add authentication and sessions per: http://mrcook.uk/simple-roda-blog-tutorial
# TODO: app features (actions, authentication, persistence) as plugins (like Roda)




