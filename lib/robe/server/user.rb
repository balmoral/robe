# Robe::Server::User provides methods for accessing/managing
# user in a session, socket channel, or task thread context
# on the server. Inspired and derived from Volt.
#

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

module Robe
  module Server
    module User

      SIGNATURE_HOOK = '~~~'

      module_function

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
        Thread.current
      end

      # Returns the current user id from current thread.
      # Returns nil if no current user id.
      # Will throw a Robe::UserError if
      def current_user_id
        user_id_signature = self.user_id_signature
        if user_id_signature.nil?
          nil
        else
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
        current_thread['user_id']
      end

      # Returns current thread meta data as a hash or nil.
      def thread_meta
        current_thread['meta']
      end

      # Sets current thread meta data to a hash or nil.
      # Returns previous value if any.
      def thread_meta=(hash)
        prev = thread_meta
        current_thread['meta'] = hash
        prev
      end

      # Sets current thread user id.
      # Returns previous id if any.
      def thread_user_id=(id)
        prev = current_thread['user_id']
        current_thread['user_id'] = id
        prev
      end

      # Returns signature as stored in thread metadata.
      # Returns nil if non meta data or no signature found.
      def user_id_signature
        meta = thread_meta
        meta && meta['user_id_signature']
      end

      # Sets user id signature in current thread meta data.
      # Returns previous value if any.
      # Will raise error if current thread has no meta data.
      def user_id_signature=(signature)
        prev = user_id_signature
        meta = thread_meta
        raise RuntimeError, "#{self}###{__method__} : no meta data set for current thread" unless meta
        meta['user_id_signature'] = signature
        prev
      end

      # Returns a SHA256 digest token generated from salted user id.
      def tokenize_user_id(user_id)
        Digest::SHA256.hexdigest salted_user_id(user_id)
      end

      # Returns a salted user id - prefixed with app secret.
      def salted_user_id(user_id)
        "#{Robe.config.app_secret}::#{user_id}"
      end
    end
  end
end
