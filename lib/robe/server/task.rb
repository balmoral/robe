require 'robe/server/tasks/manager'

module Robe; module Server
  class Task
    # Register a server task.
    #
    # @param [ Symbol ] name Symbol identifying the task.
    # @param [ Boolean ] auth Whether to verify user signature in task metadata. Defaults to true.
    #
    # @yieldparam [ Hash ] Keyword args from client over socket.
    def self.task(name, auth: true, &block)
      Robe.task_registry.register(name, auth: auth, &block)
    end

    # #api is an alias for #task
    def self.api(name, auth: true, &block)
      task(name, auth: auth, &block)
    end
    
  end
end end

