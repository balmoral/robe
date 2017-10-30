module Mongo
  module Index
    class View

      # bug in mongo ruby? :
      # limit is defined as private and causes #each (cursor stuff) to fail
      # how simple it is to make a private method public!
      public def limit
        -1
      end

    end
  end end

module Robe; module DB
  module Mongo

    class Indexes
      include Enumerable

      attr_reader :collection, :native

      def initialize(collection)
        @collection = collection
        @native = collection.native.indexes
      end

      def names
        map { |e| e['name'] }
      end

      def each(&block)
        native.each(&block)
      end

      def drop_one(name)
        reset { native.drop_one(name) }
      end

      def drop_all
        reset { native.drop_all }
      end

      # if no names given then all indexes dropped
      def drop(*names)
        if names.empty?
          drop_all
        else
          names.each do |n|
            drop_one(n.to_s)
          end
        end
      end

      # returns info about the index with given name as hash
      def info_one(name)
        native.get(name.to_s)
      end

      # returns info about all indexes as array of hashes
      def info_all
        names.map { |n| info_one(n.to_s) }
      end

      # if no names given then info for all indexes provided
      # if one name given then info as hash for index provided
      # else array of hashes of info for named indexes provided
      def info(*names)
        if names.empty?
          info_all
        elsif names.size == 1
          info_one(names.first)
        else
          names.map { |n| info_one(n) }
        end
      end

      def create_one(keys, **options)
        reset { native.create_one(keys, options.stringify_keys) }
      end

      def create_many(*models)
        reset { native.create_many(*models) }
      end

      private

      def reset
        result = yield
        collection.reset_indexes
        result
      end

    end

    class Index

      attr_reader :collection, :name

      def initialize(collection, index_name)
        @collection = collection
        @name = index_name
      end

      # returns info about the index as hash
      def info
        @info ||= collection.indexes.get(name)
      end

      def drop
        collection.indexes.drop_one(name)
      end

    end
  end
end end