module Robe; module DB
  module Mongo
    class Client
      include Robe::DB::Mongo::Util

      DEFAULT_HOST = '127.0.0.1'
      DEFAULT_PORT = '27017'

      attr_reader :host, :port, :native, :database

      def initialize(host: nil, port: nil, database: nil, logger_level: nil)
        host ||= DEFAULT_HOST
        port ||= DEFAULT_PORT
        self.logger_level = logger_level if logger_level
        @host, @port = host, port
        # additional addresses for replica set(s)
        @native = ::Mongo::Client.new("mongodb://#{host}:#{port}")
        use(database) if database
        at_exit { close }
      end

      # Returns a hash of various stats.
      def stats
        native.command('dbstats' => 1).documents.first
      end

      def use(database_name)
        database_name = database_name.to_s
        native_db = native.use(database_name) # is actually a Mongo::Client
        @database = Robe::DB::Mongo::Database.new(self, native_db)
      end

      def close
        native? do
          native.close
          @database = nil
          @native = nil
        end
      end
      alias_method :disconnect, :close
      
      def database_names
        native? do
          native.database_names.map(&:to_s)
        end
      end

      # will return info for all databases if no names given
      def database_info(*names)
        names = names.map(&:to_s)
        native? do
          info = native.list_databases
          info = info.select { |e| names.include?(e[:name]) } unless names.empty?
          names.size == 1 ? info.first : info
        end
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