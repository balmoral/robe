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


module Robe; module Server
  class App < ::Roda

    def self.start
      trace __FILE__, __LINE__, self, __method__
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

    # Register a server task.
    # `name` should be a symbol identifying the task.
    # `lambda` must be a lambda which performs the task.
    def self.task(name, lambda)
      tasks.register(name, lambda)
    end

    # :head - treat HEAD requests like GET requests with an empty response body
    plugin :head

    # :json - Allows match blocks to return arrays and hashes, using a json representation as the response body.
    plugin :json, classes: [Array, Hash, Robe::Model]

    # we expect only asset or socket requests
    route do |r|
      assets.route(r)
      sockets.route(r)
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


  end
end end

# these all add methods to App
require 'robe/server/app/tasks/db'
require 'robe/server/app/state/user'
require 'robe/server/app/state/session'

# TODO: add authentication and sessions per: http://mrcook.uk/simple-roda-blog-tutorial
# TODO: app features (actions, authentication, persistence) as plugins (like Roda)




