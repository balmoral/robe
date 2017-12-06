require 'json'
require 'robe/client/server'
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

      # Returns a Promise with result of op as value
      def self.op(target, method, *args)
        # trace __FILE__, __LINE__, self, __method__, "(target=#{target}, method=#{method}, args=#{args})"
        promise = server.perform_task(:dbop, target: target, method: method, args: args)
        promise.then do |response|
          trace __FILE__, __LINE__, self, __method__, " : target=#{target} method=#{method} args==#{args} : response[:success]=#{response[:success]} response[:error]=#{response[:error]} response[:data]=#{response[:data].class}"
          response = response.symbolize_keys
          if response[:success]
            Robe::Promise.value(response[:data])
          else
            Robe::Promise.error(response[:error])
          end
        end.fail do |error|
          trace __FILE__, __LINE__, self, __method__, " : target=#{target} method=#{method} args==#{args} : error : #{error}"
          Robe::Promise.error(error)
        end
      end

    end
  end

  module_function

  def db
    Robe::Client::DB
  end
end