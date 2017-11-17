require 'robe/common/redux/atom'
require 'robe/client/app/user'

module Robe
  module Client
    class App
      class State < Robe::Redux::Atom

        WEBSOCKET_CLOSED = 1001
        ERRORS = {
          WEBSOCKET_CLOSED => 'Web socket closed by server.'
        }

        attr :user
        attr :server_errors
        attr :sign_in_invalid_user
        attr :sign_in_invalid_password

        def initialize
          super(server_errors: {})
        end

        def user?
          !!user
        end

        def signed_in?
          user?
        end

        def signed_out?
          !signed_in?
        end

        def error_message(error_code)
          ERRORS[error_code]
        end

        def server_errors?
          server_errors.size > 0
        end

        def add_server_error(error_code, message = nil)
          message ||= error_message(error_code)
          mutate!(server_errors: server_errors.merge({error_code => message}))
        end

        def notify_web_socket_error
          add_server_error(WEBSOCKET_CLOSED)
        end

        def websocket_closed?
          server_errors.keys.include?(WEBSOCKET_CLOSED)
        end
        
        def clear_server_errors
          mutate!(server_errors: {})
        end

        def sign_in_invalid_user?
          !!sign_in_invalid_user
        end

        def sign_in_invalid_password?
          !!sign_in_invalid_password
        end

        def set_user(user)
          mutate!(user: user) do
            clear_sign_in_errors
          end
        end
        
        def clear_sign_in_errors
          mutate! do
            self.sign_in_invalid_user = nil
            self.sign_in_invalid_password = nil
          end
        end
        
      end
    end
  end
end