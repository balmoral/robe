# Robe::Server::Thread provides methods for accessing/managing
# current thread data, especially user_id and other meta data
# from client requests. Derived from Volt.

# For use mainly by Robe::Server::Auth.
# TODO: lots

module Robe
  module Server
    module Memory

      # module_function privatises methods
      # when modules/classes include/extend
      extend self

      def stats
        GC.stat
      end

      def compact
        GC.compact
      end

    end
  end

  module_function

  def thread
    @thread ||= Robe::Server::Thread
  end
end
