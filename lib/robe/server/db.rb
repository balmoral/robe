require 'robe/server/db/mongo'
require 'robe/common/db/ops'
require 'robe/server/db/mongo/patches'

# isomorphic of Robe::Client::DB
# TODO: make database backend (mongo/sequel) plugable

module Robe
  module Server
    class DB
      include Robe::Shared::DB::Ops

      class << self
        def config
          @config ||= Robe::Server::Config
        end

        def mongo_client
          if config.use_mongo?
            unless defined?(@mongo_client)
              trace __FILE__, __LINE__, self, __method__, " : creating mongo client for hosts=#{config.mongo_hosts} database=#{config.mongo_database}"
              @mongo_client = Robe::DB::Mongo::Client.new(
                hosts: config.mongo_hosts,
                database: config.mongo_database,
                user: config.mongo_user,
                password: config.mongo_password
              )
              if @mongo_client
                trace __FILE__, __LINE__, self, __method__, " : created mongo client for host=#{config.mongo_hosts} database=#{config.mongo_database}"
              else
                raise Robe::DBError, "#{__FILE__}[#{__LINE__}] : could not create mongo client for host=#{config.mongo_hosts} database='#{config.mongo_database}'"
              end
              unless @mongo_client.database
                raise Robe::DBError, "#{__FILE__}[#{__LINE__}] : mongo client does not host database named '#{config.mongo_database}'"
              end
            end
            @mongo_client
          else
            raise Robe::ConfigError, 'config.use_mongo must be set to true to access mongo client'
          end
        end

        def mongo_db
          if config.use_mongo?
            mongo_client.database
          else
            raise Robe::ConfigError, 'config.use_mongo must be set to true to access mongo database'
          end
        end

        # Returns result of mongo operation as a hash:
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
        # Synchronous operation - no promise.
        #
        def sync_op(target, method, *args)
          trace __FILE__, __LINE__, self, __method__, " : target=#{target} method=#{method} args[0]=#{args[0]}"
          target = target.to_s
          target = case target
            when 'database'
              mongo_db
            else
              collection = mongo_db.collection(target)
              unless collection
                raise DBError, "'#{target}' is not a mongo database collection"
              end
              collection
          end
          begin
            target.send(method, *args)
          rescue Mongo::Error => e
            raise DBError, "'Mongo::Error => #{e}"
          end
        end

        # Returns result of mongo operation as a Robe::Promise -
        # i.e. is an asynchronous operation.
        # `target` should be one of [database, collection, index]
        # `method` should be a method appropriate to target
        # `args` should be an array in json format
        def op(target, method, *args)
          sync_op(target, method, *args).as_promise
        end

      end
    end
  end

  module_function

  def db
    @db ||= Robe::Server::DB
  end

end