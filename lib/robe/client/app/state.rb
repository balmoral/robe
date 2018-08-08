require 'robe/common/state/atom'
require 'robe/client/app/user'

module Robe
  module Client
    class App
      class State < Robe::State::Atom

        WEBSOCKET_OPEN          = 1001
        WEBSOCKET_CLOSED        = 1002
        WEBSOCKET_RECONNECTING  = 1003
        WEBSOCKET_ERROR         = 1004

        attr :user
        attr :server_errors
        attr :websocket_status
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

        def server_errors?
          server_errors.size > 0
        end

        def add_server_error(code, message = nil)
          message ||= code.to_s
          mutate!(server_errors: server_errors.merge({code => message}))
        end

        def websocket_status?
          !!websocket_status
        end

        def set_socket_status(code, message = nil)
          message ||= code.to_s
          mutate!(websocket_status: { code => message })
        end

        def notify_websocket_open
          set_socket_status(WEBSOCKET_OPEN, 'Web socket open.')
        end

        def notify_websocket_closed
          set_socket_status(WEBSOCKET_CLOSED, 'Web socket closed.')
        end

        def notify_websocket_reconnect(attempt:)
          set_socket_status(WEBSOCKET_RECONNECTING, "reconnecting socket: attempt ##{attempt}." )
        end

        def notify_websocket_error(error)
          set_socket_status(WEBSOCKET_ERROR, "socket error: #{error}")
        end

        def websocket_open?
          websocket_status? && websocket_status[WEBSOCKET_OPEN]
        end

        def websocket_closed?
          websocket_status? && websocket_status[WEBSOCKET_CLOSED]
        end

        def websocket_reconnecting?
          websocket_status? && websocket_status[WEBSOCKET_RECONNECTING]
        end

        def websocket_error?
          websocket_status? && websocket_status[WEBSOCKET_ERROR]
        end

        def websocket_status_message
          websocket_status? ? websocket_status.values.first : 'unknown websocket status'
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
