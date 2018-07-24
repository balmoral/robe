require 'json'
require 'robe/client/server'
require 'robe/client/util/logger'
require 'robe/common/db/ops'

# isomorphic of Robe::Server::DB
# TODO: make database backend (mongo/sequel) plugable

module Robe
  module Client
    class DB
      include Robe::Shared::DB::Ops

      def self.server
        Robe.server
      end

      # Perform a database operation on the server.
      # Returns a Promise with result of op as value.
      # TODO: auth or not to auth?
      def self.op(target, method, *args)
        # trace __FILE__, __LINE__, self, __method__, "(target=#{target}, method=#{method}, args=#{args})"
        promise = server.perform_task(:dbop, auth: true, target: target, method: method, args: args)
        promise.then do |response|
          response = response.symbolize_keys
          if response[:success]
            response[:data].to_promise
          else
            response[:error].to_promise_error
          end
        end.fail do |error|
          Robe.logger.error("#{__FILE__}[#{__LINE__}] #{self.name}##{__method__} : #{error} ")
          error.to_promise_error
        end
      end

    end
  end

  module_function

  def db
    @db ||= Robe::Client::DB
  end
end