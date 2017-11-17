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
          Robe.app.perform_task(:sign_out, user: signature)
          Robe.app.state.mutate!(user: nil)
        end

        # Returns a promise with current User if successful.
        # See Robe::Server::User for response structures.
        def self.sign_in(id, password)
          trace __FILE__, __LINE__, self, __method__, "(#{id}, #{password})"
          if Robe.app.user?
            raise Robe::UserError, 'previous user must be signed out before sign in of new user'
          end
          trace __FILE__, __LINE__, self, __method__, "(#{id}, #{password})"
          Robe.app.perform_task(:sign_in, id: id, password: password).then do |result|
            trace __FILE__, __LINE__, self, __method__, " result=#{result}"
            result = result.symbolize_keys
            case result[:status]
              when 'success'
                # construct new instance with response from task
                # (expects :id, :name, :signature and optional :data)
                user = new(**result[:user])
                trace __FILE__, __LINE__, self, __method__, " user=#{user.to_h}"
                Robe.app.state.set_user(user)
                trace __FILE__, __LINE__, self, __method__
                Robe.app.cookies[:user_id] = user.id, {
                  expires: user.expiry,
                  secure: true
                }
                trace __FILE__, __LINE__, self, __method__
                user.to_promise
              when 'server_error'
                Robe.app.state.mutate!(user: nil) do
                  Robe.app.state.server_errors << result[:error]
                end
                result[:error].to_promise_error
              when 'invalid user'
                Robe.app.state.mutate!(user: nil, sign_in_invalid_user: true)
                'invalid user'.to_promise_error
              when 'invalid password'
                Robe.app.state.mutate!(user: nil, sign_in_invalid_password: true)
                'invalid password'.to_promise_error
            end
          end.fail do |error|
            trace __FILE__, __LINE__, self, __method__, " error=#{error}"
            Robe.app.state.mutate!(user: nil) do
              Robe.app.state.server_errors << error
            end
            Robe.app.cookies.delete(:user_id)
            error.to_promise_error
          end
        end

      end

    end
  end
end