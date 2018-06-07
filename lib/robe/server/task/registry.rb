# Adapted from Volt. We don't use drb for now.

require 'singleton'

# The tasks module takes incoming messages from the
# task socket channel, dispatches them to the
# registered task lambda, and sends responses back
# to the client(s).

module Robe
  module Server
    module Tasks
      class Registry
        include Singleton

        attr_reader :tasks

        def initialize
          @tasks = {}
        end

        def [](task_name)
          @tasks[task_name.to_sym]
        end
        
        # Register a server task.
        #
        # @param [ Symbol ] name Symbol identifying the task.
        # @param [ Boolean ] auth Whether to verify user signature in task metadata. Defaults to true.
        # @param [ Lambda ] lambda To perform the task. If nil a block must be given.
        #
        # @yieldparam [ Hash ] Keyword args from client over socket.
        def register(name, lambda = nil, auth:, &block)
          unless lambda || block
            raise ArgumentError, 'task requires a lambda or block'
          end
          @tasks[name.to_sym] = { lambda: lambda || block, auth: auth }
        end

      end
    end
  end
  
  module_function

  def task_registry
    @task_registry ||= Robe::Server::Tasks::Registry.instance
  end
end
