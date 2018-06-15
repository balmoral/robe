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

      # Returns a Promise with result of op as value
      def self.op(target, method, *args)
        # trace __FILE__, __LINE__, self, __method__, "(target=#{target}, method=#{method}, args=#{args})"
        promise = server.perform_task(:dbop, target: target, method: method, args: args)
        promise.then do |response|
          if target.to_sym == :production_schedules && args.first.is_a?(Hash) && args.first[:product_id] == 'bb9fb6594b8866c45302d228'
            trace __FILE__, __LINE__, self, __method__, " : target=#{target} method=#{method} args=#{args} : response[:success]=#{response[:success]} response[:error]=#{response[:error]} response[:data]=#{response[:data].class}"
          end
          response = response.symbolize_keys
          if response[:success]
            response[:data].to_promise
          else
            response[:error].to_promise_error
          end
        end.fail do |error|
          trace __FILE__, __LINE__, self, __method__, " : target=#{target} method=#{method} args==#{args} : error : #{error}"
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