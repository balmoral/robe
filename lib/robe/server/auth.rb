# Robe::Server::Auth provides methods for accessing/managing
# user in a session, socket channel, or task thread context
# on the server. Derived from Volt.
#

# TODO: add authentication and sessions per: http://mrcook.uk/simple-roda-blog-tutorial
# TODO: app features (actions, authentication, persistence) as plugins (like Roda)

# EXAMPLE USAGE
=begin
 def sign_in(id:, password:)
  trace __FILE__, __LINE__, self, __method__, " id=#{id} password=#{password}"
  _testing = true
  password = Password.find_one(user_id: id)
  if password
    if password.hash == Robe::Server::User.password_hash(password)
      user = User.find_one(user_id: id)
      if user
        sign_in_success_response(id, data: user.to_h)
      else
        sign_in_error_response(id, "unexpected error: user #{id} not found in users database")
      end
    else
      sign_in_invalid_password_response(user_id)
    end
  else
    sign_in_invalid_user_response(user_id)
  end
end
=end

require 'digest'
require 'bcrypt'
require 'robe/server/thread'

module Robe
  module Server
    module Auth

      SIGNATURE_HOOK = '~-~-~'

      module_function

      def valid_user_signature?(user_id, given_user_signature)
        given_user_signature == user_signature(user_id)
      end
      
      def sign_in_success_response(user_id, data: nil)
        trace __FILE__, __LINE__, self, __method__
        result = {
          status: 'success',
          user: {
            id: user_id,
            signature: user_signature(user_id),
            data: data
          }
        }
        trace __FILE__, __LINE__, self, __method__, " result=#{result}"
        result
      end

      def sign_in_error_response(user_id, message)
        {
          id: user_id,
          status: 'error',
          message: message
        }
      end

      def sign_in_invalid_user_response(user_id)
        {
          id: user_id,
          status: 'invalid user'
        }
      end

      def sign_in_invalid_password_response(user_id)
        {
          id: user_id,
          status: 'invalid password'
        }
      end

      # Returns a password hash suited to storing in database.
      def password_hash(password)
        BCrypt::Password.create(password)
      end

      # Returns a signature based on salted and tokenized user id
      # which is suitable for use as a user id in session cookies
      # and socket requests.
      def user_signature(user_id)
        trace __FILE__, __LINE__, self, __method__, "(#{user_id})"
        unless Robe.config.app_secret
          trace __FILE__, __LINE__, self, __method__, 'app secret not configured for server'
          raise RuntimeError, 'app secret not configured for server'
        end
        token = tokenize_user_id(user_id)
        result = "#{user_id}#{SIGNATURE_HOOK}#{token}"
        trace __FILE__, __LINE__, self, __method__, " result=#{result}"
        result
      end

      def current_thread
        Robe.thread.current
      end

      # Returns the current user id from current thread.
      # Returns nil if no current user id.
      # Will throw a Robe::UserError if user_id is incorrectly signed
      def current_user_id
        user_id_signature = self.user_id_signature
        if user_id_signature
          index = user_id_signature.index(SIGNATURE_HOOK)
          # if no index, the meta_data/cookie is invalid
          if index
            user_id = user_id_signature[0...index]
            token = user_id_signature[(index + 1)..-1]
            # Make sure the user token in the signature matches token generated with app secret.
            # If the tokens don't match the user id has been tampered with - raise a UserError.
            unless token == tokenize_user_id(user_id)
              raise Robe::UserError, 'User id or token is incorrectly signed. It may have been tampered with, the app secret changed, or generated in a different app.'
            end
            user_id
          end
        end
      end

      def thread_user_id
        current_thread.user_id
      end

      def thread_user_id=(id)
        current_thread.user_id = id
      end

      # Returns signature as stored in thread metadata.
      # Returns nil if non meta data or no signature found.
      def user_id_signature
        meta = current_thread.meta
        meta && meta['user_id_signature']
      end

      # Sets user id signature in current thread meta data.
      # Will create new meta data if current thread has none.
      def user_id_signature=(signature)
        meta = current_thread.meta
        current_thread.meta = meta = {} unless meta
        meta['user_id_signature'] = signature
      end

      # Returns a SHA256 digest token generated from salted user id.
      def tokenize_user_id(user_id)
        salted_id = salted_user_id(user_id)
        Digest::SHA256.hexdigest(salted_id)
      end

      # Returns a salted user id - prefixed with app secret.
      def salted_user_id(user_id)
        "#{Robe.config.app_secret}::#{user_id}"
      end
    end
  end

  module_function

  def auth
    @auth ||= Robe::Server::Auth
  end
end
