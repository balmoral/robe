# Robe::Server::Thread provides methods for accessing/managing
# current thread data, especially user_id and other meta data
# from client requests. Derived from Volt.

# For use mainly by Robe::Server::Auth.
# TODO: lots

module Robe
  module Server
    module Thread

      # module_function privatises methods
      # when modules/classes include/extend
      extend self

      def current
        ::Thread.current
      end

      def user
        current['robe_user'] ||= {}
      end

      def data
        current['robe_data']
      end

      def data=(data)
        current['robe_data'] = data
      end

      def user_id
        user['id']
      end

      def user_id=(id)
        user['id'] = id
      end

      def user_signature
        user['signature']
      end

      def user_signature=(signature)
        user['signature'] = signature
      end
    end
  end

  module_function

  def thread
    @thread ||= Robe::Server::Thread
  end
end
