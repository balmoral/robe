require 'robe/client/server/tasks'

# interface between client and server
module Robe
  module Client
    module Server

      module_function

      # Returns a promise
      def perform_task(name, auth: nil, **args)
        # trace __FILE__, __LINE__, self, __method__, "(#{name}, auth: #{auth}, args: #{args})"
        Robe.tasks.perform(name, auth: auth, **args)
      end

    end
  end

  module_function

  def server
    @server ||= Robe::Client::Server
  end
end