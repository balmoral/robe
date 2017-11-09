# Robe::Server::User provides methods for accessing/managing
# user in a session, socket channel, or task thread context
# on the server. Inspired and derived from Volt.

require 'digest'
require 'bcrypt'

module Robe
  module Server
    module User

      SIGNATURE_HOOK = '~~~'

      module_function

      # Returns a password hash suited to storing in database.
      def password_hash(password)
        BCrypt::Password.create(password)
      end

      # Returns a signature based on salted and tokenized user id
      # which is suitable for use as a user id in session cookies
      # and socket requests.
      def user_signature(user)
        unless Robe.config.app_secret
          raise RuntimeError, '"app secret not configured for server" '
        end
        user_id = user.is_a?(String) ? user : user.id
        token = tokenize_user_id(user_id)
        "#{user_id}#{SIGNATURE_HOOK}#{token}"
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
