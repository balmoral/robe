require 'robe/server/task/registry'

module Robe; module Server
  class Api
    # Register a server task.
    #
    # @param [ Symbol ] name Symbol identifying the task.
    # @param [ Boolean ] auth Whether to verify user signature in task metadata. Defaults to true.
    # @param [ Lambda ] lambda To perform the task. If nil a block must be given.
    #
    # @yieldparam [ Hash ] Keyword args from client over socket.
    def self.task(name, lambda = nil, auth: true, &block)
      Robe.task_registry.register(name, lambda, auth: auth, &block)
    end

    # #api is an alias for #task
    def self.api(name, lambda = nil, auth: true, &block)
      task(name, lambda, auth: auth, &block)
    end
    
  end
end end

