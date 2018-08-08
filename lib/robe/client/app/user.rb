require 'robe/common/auth'
require 'robe/common/model'
require 'robe/common/promise'

module Robe
  module Client
    class App
      class User < Robe::Model
        attr :id, :signature, :data, :expiry

        def initialize(**args)
          args[:expiry] ||= Time.now + 60 * 60 * 24
          super
        end

        def sign_out
          Robe.app.perform_task(:sign_out, auth: true, user: signature)
          Robe.app.state.mutate!(user: nil)
        end

        # Returns a promise with current User if successful.
        # See Robe::Server::User for response structures.
        def self.sign_in(id, password)
          trace __FILE__, __LINE__, self, __method__, "(#{id}, #{password})"
          if Robe.app.user?
            msg = 'previous user must be signed out before sign in of new user'
            trace __FILE__, __LINE__, self, __method__, " : #{msg}"
            raise Robe::UserError, msg
          end
          # trace __FILE__, __LINE__, self, __method__, "(#{id}, #{password})"
          Robe.app.perform_task(:sign_in, auth: false, id: id, password: password).then do |result|
            # trace __FILE__, __LINE__, self, __method__, " result=#{result}"
            result = result.symbolize_keys
            case result[:status]
              when Robe::Auth::SIGN_IN_SUCCESS
                # construct new instance with response from task
                # (expects :id, :name, :signature and optional :data)
                user = new(**result[:user])
                # trace __FILE__, __LINE__, self, __method__, " user=#{user.to_h}"
                Robe.app.state.set_user(user)
                Robe.app.cookies[:user_id] = user.id, {
                  expires: user.expiry,
                  secure: true
                }
                user
              when Robe::Auth::SIGN_IN_INVALID_USER
                trace __FILE__, __LINE__, self, __method__, " invalid user"
                Robe.app.state.mutate!(user: nil, sign_in_invalid_user: true)
                result[:status].to_promise_error
              when Robe::Auth::SIGN_IN_INVALID_PASSWORD
                trace __FILE__, __LINE__, self, __method__, " invalid password"
                Robe.app.state.mutate!(user: nil, sign_in_invalid_password: true)
                result[:status].to_promise_error
              else
                msg = "unknown results status #{result[:status]}"
                trace __FILE__, __LINE__, self, __method__, " : runtime error : #{msg}"
                raise Robe::RuntimeError, msg
            end
          end.fail do |error|
            trace __FILE__, __LINE__, self, __method__, " error=#{error}"
            Robe.app.state.mutate!(user: nil) do
              if error.is_a?(Hash)
                Robe.app.state.add_server_error(error[:code], error[:message])
              else
                Robe.app.state.add_server_error(-1, error.to_s)
              end
            end
            Robe.app.cookies.delete(:user_id)
            error.to_promise_error
          end
        end

      end
    end
  end
end