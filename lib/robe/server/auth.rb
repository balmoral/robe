# Robe::Server::Auth provides methods for accessing/managing
# user in a session, socket channel, or task thread context
# on the server. Derived from Volt.
#

# TODO: add authentication and sessions per: http://mrcook.uk/simple-roda-blog-tutorial
# TODO: app features (actions, authentication, persistence) as plugins (like Roda)

# EXAMPLE USAGE
=begin
 def sign_in(id:, password:)
  password = Password.find_one(user_id: id)
  if password
    if password.hash == Robe::Server::Auth.generate_password_hash(password)
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
require 'robe/common/auth'

module Robe
  module Server
    module Auth
      include Robe::Auth
      extend Robe::Auth

      # module_function privatises methods
      # when modules/classes include/extend
      extend self

      def valid_user_signature?(user_id, given_user_signature)
        given_user_signature == generate_user_signature(user_id)
      end

      def valid_password?(password, stored_hash)
        BCrypt::Password.new(stored_hash) == password
      end

      # Returns a hash with
      #   status: SIGN_IN_SUCCESS
      # and
      #   user: {
      #      id: user_id,
      #      signature: generate_user_signature(user_id),
      #      data: user_data
      #   }
      def sign_in_success(user_id, user_data = nil)
        {
          status: SIGN_IN_SUCCESS,
          user: {
            id: user_id,
            signature: generate_user_signature(user_id),
            data: user_data
          }
        }
      end

      def sign_in_invalid_user(user_id)
        {
          status: SIGN_IN_INVALID_USER,
          user: { id: user_id },
        }
      end

      def sign_in_invalid_password(user_id)
        {
          status: SIGN_IN_INVALID_PASSWORD,
          user: { id: user_id },
        }
      end

      # Returns a password hash string suited to storing in database.
      def generate_password_hash(password)
        BCrypt::Password.create(password).to_s
      end

      # Returns a signature based on salted and tokenized user id
      # which is suitable for use as a user id in session cookies
      # and socket requests.
      def generate_user_signature(user_id)
        # trace __FILE__, __LINE__, self, __method__, "(#{user_id})"
        unless Robe.config.app_secret
          trace __FILE__, __LINE__, self, __method__, 'app secret not configured for server'
          raise RuntimeError, 'app secret not configured for server'
        end
        token = tokenize_user_id(user_id)
        result = "#{user_id}#{SIGNATURE_HOOK}#{token}"
        # trace __FILE__, __LINE__, self, __method__, " result=#{result}"
        result
      end

      # Returns the user_id extracted from a user signature.
      # Will throw a Robe::UserError if signature is not correctly constructed or signed
      def extract_user_id(signature)
        # trace __FILE__, __LINE__, self, __method__, "(#{signature})"
        index = signature.index(SIGNATURE_HOOK)
        # if no index, the signature is invalid
        result = if index
          user_id = signature[0...index]
          token = signature[(index + SIGNATURE_HOOK.length)..-1]
          check = tokenize_user_id(user_id)
          # trace __FILE__, __LINE__, self, __method__, " user_id=#{user_id} token=#{token}, check=#{check} eq=#{token == check}"
          token == check ? user_id : nil
        end
        unless result
          raise Robe::UserError, 'Invalid user signature: it may have been tampered with, the app secret changed, or generated in a different app.'
        end
        result
      end

      # Returns the current user id from current thread.
      # Returns nil if no current user.
      def current_user_id
        thread.user_id
      end

      # Returns current thread
      def thread
        Robe.thread
      end

      def thread_user_id
        thread.user_id
      end

      def thread_user_signature
        thread.user_signature
      end

      # sets thread user signature and id (extracted from signature)
      def thread_user_signature=(signature)
        thread.user_signature = signature
        thread.user_id = signature && extract_user_id(signature)
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
