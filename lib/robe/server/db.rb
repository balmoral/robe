require 'robe/server/db/mongo'
require 'robe/common/db/ops'
require 'robe/server/db/mongo/patches'
require 'concurrent'

# isomorphic of Robe::Client::DB
# TODO: make database backend (mongo/sequel) plugable

module Robe
  module Server
    class DB
      include Robe::DB::Ops

      class << self

        def start
          init_ops
          init_mongo_client
          init_mongo_collections
        end

        def config
          @config ||= Robe::Server::Config
        end

        def mongo_client
          @mongo_client
        end

        def mongo_db
          if config.use_mongo?
            mongo_client.database
          else
            raise Robe::ConfigError, 'config.use_mongo must be set to true to access mongo database'
          end
        end

        # Returns result of mongo operation as a hash in a promise:
        # {
        #   success: true or false
        #   data: the result of the operation if success true
        #   error: error message if success false
        # }
        #
        # `target` should be one of [database, collection, index]
        # `method` should be a method appropriate to target
        # `args` should be an array in json format
        #
        # Returns a promise.
        def op(arg_target, method, *args)
          promise = Robe::Promise.new
          __perform_op do
            target = case arg_target.to_s
              when 'database'
                mongo_db
              else
                collection = mongo_db.collection(arg_target)
                unless collection
                  msg = "#{__FILE__}[#{__LINE__}] : '#{arg_target}' is not a mongo database collection"
                  promise.reject(msg)
                end
                collection
            end
            if target
              begin
                result = target.send(method, *args)
                promise.resolve(result)
              rescue Mongo::Error => e
                msg = "#{__FILE__}[#{__LINE__}] : 'Mongo::Error => #{e}"
                Robe.logger.error(msg)
                promise.reject(msg)
              end
            end
          end
          # trace __FILE__, __LINE__, self, __method__, " : arg_target=#{arg_target} : promise.class=#{promise.class}"
          promise
        end

        def __perform_op(&block)
          if @op_thread_pool
            @op_thread_pool.post do
              block.call
            end
          else
            Thread.new do
              block.call
            end
          end
        end

        def min_threads
          [1, config.db_op_min_threads].max
        end

        def max_threads
          [1, config.db_op_max_threads].max
        end

        def init_mongo_client
          # trace __FILE__, __LINE__, self, __method__, " : creating mongo client for hosts=#{config.mongo_hosts} database=#{config.mongo_database}"
          @mongo_client = Robe::DB::Mongo::Client.new(
            hosts: config.mongo_hosts,
            database: config.mongo_database,
            user: config.mongo_user,
            password: config.mongo_password,
            min_pool_size: min_threads,
            max_pool_size: max_threads
          )
          if @mongo_client
            # trace __FILE__, __LINE__, self, __method__, " : created mongo client for host=#{config.mongo_hosts} database=#{config.mongo_database}"
          else
            raise Robe::DBError, "#{__FILE__}[#{__LINE__}] : could not create mongo client for host=#{config.mongo_hosts} database='#{config.mongo_database}'"
          end
          unless @mongo_client.database
            raise Robe::DBError, "#{__FILE__}[#{__LINE__}] : mongo client does not host database named '#{config.mongo_database}'"
          end
        end

        def init_mongo_collections
          required = []
          required << Robe::DB::Models::TaskLog if Robe.config.log_tasks?
          unless required.empty?
            names = required.map(&:collection_name)
            op(:database, :create_collections, *names)
          end  
        end

        def init_ops
          @op_mutex = Mutex.new
          # limit threads to mongo connection pool size
          @op_thread_pool = if Robe.config.db_op_max_threads > 0
            Concurrent::CachedThreadPool.new(
              min_threads: min_threads,
              max_threads: max_threads
            )
          end
        end

      end
    end
  end

  module_function

  def db
    @db ||= Robe::Server::DB
  end

end