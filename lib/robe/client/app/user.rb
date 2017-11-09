require 'robe/common/model'
require 'robe/common/promise'

module Robe
  module Client
    module App

      class User < Robe::Model
        attr :id, :name, :signature, :data, :expiry

        def initialize(**args)
          args[:expiry] ||= Time.now + 60 * 60 * 24
          super
        end

        def sign_out
          Robe.app.perform_task(:sign_out, user: signature)
          Robe.app.state.mutate!(user: nil)
        end

        # Returns a promise with current User as argument if successful.
        def self.sign_in(id, password)
          if Robe.app.user?
            raise Robe::UserError, 'previous user must be signed out before sign in of new user'
          end
          Robe.app.perform_task(:sign_in, id: id, password: password).then do |result|
            if result[:success]
              # construct new instance with response from task
              # (expects :id, :name, :signature and optional :data)
              user = new(**result[:data])
              Robe.app.state.mutate!(
                sign_in_error: nil,
                user: user
              )
              Robe.app.cookies[:user_id] = user.id, {
                expires: user.expiry,
                secure: true
              }
              user.as_promise
            else
              Robe.app.state.mutate!(
                user: nil,
                sign_in_error: result[:error]
              )
              Robe.app.cookies.delete(:user_id)
              error.as_promise_error
            end
          end.fail do |error|
            Robe.app.state.mutate!(
              user: nil,
              sign_in_error: error
            )
            Robe.app.cookies.delete(:user_id)
            error.as_promise_error
          end
        end

      end

    end
  end
end