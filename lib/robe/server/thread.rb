# Robe::Server::Thread provides methods for accessing/managing
# current thread data, especially user_id and other meta data
# from client requests. Derived from Volt.

# For use by Robe::Server::User.

module Robe
  module Server
    module Thread

      module_function

      def current
        ::Thread.current
      end

      def user_id
        current['user_id']
      end

      def user_id=(id)
        current['user_id'] = id
      end

      # Returns current thread meta data as a hash or nil.
      def meta
        current['meta']
      end

      def meta=(hash)
        current['meta'] = hash
      end

    end
  end

  module_function

  def thread
    @thread ||= Robe::Server::Thread
  end
end
