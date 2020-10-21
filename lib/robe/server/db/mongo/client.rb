module Robe; module DB
  module Mongo
    class Client
      include Robe::DB::Mongo::Util

      LOCAL_HOST = '127.0.0.1:27017'
      DEFAULT_POOL_SIZE = 
      attr_reader :uri, :native, :database

      # hosts is array of strings with 'address:port'
      # - %w(127.0.0.1:27017)
      # - or multiple hosts for replica sets...
      # - e.g. %w(xy123456-a0.mongolab.com:49664 xy654321-a0.mongolab.com:49664)
      def initialize(hosts:, database:, user:, password:, min_pool_size: 1, max_pool_size: 5, logger_level: nil)
        self.logger_level = logger_level if logger_level
        trace __FILE__, __LINE__, self, __method__, " hosts=#{hosts} user=#{user} database=#{database}"
        ::Mongo::Logger.logger.level = ::Logger::INFO
        if hosts[0].include?('mongodb') # ATLAS
          ::Mongo::Client.new(
            hosts,
            database: database,
            user: user,
            password: password,
            retry_writes: false,
            auth_source: 'admin',
            ssl: true
          ) do |native|
            trace __FILE__, __LINE__, self, __method__, " connected: native=#{native}"
            @native = native
            @database ||= Robe::DB::Mongo::Database.new(self, native.database)
            at_exit do
              trace __FILE__, __LINE__, self, __method__, ' : disconnecting mongo client'
              close
            end
          end
        else
          ::Mongo::Client.new(
            hosts,
            database: database,
            user: user,
            password: password,
            min_pool_size: min_pool_size,
            max_pool_size: max_pool_size,
            retry_writes: false
          ) do |native|
            trace __FILE__, __LINE__, self, __method__, " connected: native=#{native}"
            @native = native
            @database ||= Robe::DB::Mongo::Database.new(self, native.database)
            at_exit do
              trace __FILE__, __LINE__, self, __method__, ' : disconnecting mongo client'
              close
            end
          end
        end    
      end

      # Returns a hash of various stats.
      def stats
        native.command('dbstats' => 1).documents.first
      end

      def close
        native? do
          native.close
          @native = nil
        end
      end
      alias_method :disconnect, :close
      
      def database_names
        native.database_names.map(&:to_s)
      end

      # will return info for all databases if no names given
      def database_info(*names)
        names = names.map(&:to_s)
        info = native.list_databases
        info = info.select { |e| names.include?(e[:name]) } unless names.empty?
        names.size == 1 ? info.first : info
      end

      def native?(&block)
        if block
          raise "mongo client is not connected" unless native
          block.call
        else
          !!native
        end
      end
      
      def command(selector, **opts)
        native.command(selector, opts)
      end

    end
  end
end end