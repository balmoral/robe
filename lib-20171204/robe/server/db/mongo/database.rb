module Robe; module DB
  module Mongo
    class Database

      attr_reader :client, :native

      def initialize(client, native)
        @client = client
        @native = native
      end

      def command(selector, **opts)
        native.command(selector, opts)
      end

      # Returns a hash of various stats.
      def stats
        native.command('dbstats' => 1).documents.first
      end

      # returns hash of Collection's keyed by collection name
      def collections
        unless @collections
          @collections = {}
          native.collections.each do |c|
            @collections[c.name.to_s] = Robe::DB::Mongo::Collection.new(self, c)
          end
        end
        @collections
      end

      def collection(name, create: false)
        collection = collections[name.to_s]
        if collection.nil? && create
          collection = create_collection(name)
        end
        collection
      end

      # Returns a Collection with given name, or nil
      def [](collection_name)
        collection(collection_name)
      end

      def reset_collections
        @collections = nil
      end

      # Returns all collection names as an array of strings.
      def collection_names
        collections.keys
      end

      # Create a collection and return it.
      def create_collection(name)
        collection= native.collection(name)
        collection.create
        collections[name] = Robe::DB::Mongo::Collection.new(self, collection)
      end

      def create_collections(*names)
        names.each do |name|
          create_collection(name)
        end
      end
      
      def drop_collection(collection_name)
        # collection will remove itself from our collections
        collection = self[collection_name]
        collection.drop if collection
      end

      def drop_collections(*collection_names)
        collection_names.each do |name|
          drop_collection(name)
        end
      end

      def drop_all_collections
        drop_collections(*collection_names)
      end

      def collection_stats(*collection_names)
        collection_names = self.collection_names if collection_names.empty?
        stats = collection_names.map { |n| self[n].stats }
        collection_names.size == 1 ? stats.first : stats
      end

      def collection_count(collection_name)
        self[collection_name].count
      end

    end
  end
end end