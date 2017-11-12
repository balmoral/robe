require 'robe/client/tasks'

# interface between client and server
module Robe
  module Client
    module Server

      module_function

      # Returns a promise
      def perform_task(name, **kwargs)
        trace __FILE__, __LINE__, self, __method__, "(#{name}, #{kwargs})"
        Robe.tasks.perform(name, **kwargs)
      end

    end
  end

  module_function

  def server
    @server ||= Robe::Client::Server
  end
end