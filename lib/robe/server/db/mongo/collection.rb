
module Robe; module DB
  module Mongo
    class Collection
      include Robe::DB::Mongo::Util

      attr_reader :database, :name, :native

      def initialize(database, native_collection)
        @database = database
        @native = native_collection
        @name = native.name
      end

      def command(selector, **opts)
        native.command(selector, opts)
      end

      def namespace
        native.namespace
      end

      def stats
        database.command(collstats: name).documents.first
      end

      def indexes
        @indexes ||= Robe::DB::Mongo::Indexes.new(self)
      end

      def find(filter = nil, options = nil)
        view = native.find(filter, options || {})
        view.to_a
      end

      def count(filter = nil, options = nil)
        native.count(filter, options || {})
      end

      # Returns the inserted id
      def insert_one(document, options = nil)
        native.insert_one(document, options || {}).inserted_id
      end

      # Returns the inserted ids as an array
      def insert_many(documents, options = nil)
        native.insert_many(documents, options || {}).inserted_ids
      end

      # Returns the deleted count
      def delete_one(filter = nil, options = nil)
        native.delete_many(filter, options || {}).deleted_count
      end

      # Returns the deleted count
      def delete_many(filter = nil, options = nil)
        native.delete_many(filter, options || {}).deleted_count
      end

      # Returns hash with :matched_count, :modified_count, :upserted_count
      def update_many(filter, update, options = nil)
        result = native.update_many(filter, update, options || {})
        update_result(result)
      end

      # Returns hash with :matched_count, :modified_count, :upserted_count
      def update_one(filter, update, options = nil)
        result = native.update_one(filter, update, options || {})
        update_result(result)
      end

      # private api

      def update_result(result)
        h = {}
        [:matched_count, :modified_count, :upserted_count].each do |k|
          h[k] = result.send(k)
        end
        h
      end

      def reset_indexes
        @indexes = nil
      end

      def index_names
        indexes.names
      end

      def drop_index(index_name)
        indexes.drop_one(index_name)
      end

      def drop_indexes
        indexes.drop_all
      end

      def index_info(*names)
        indexes.index_info(names)
      end

      def create_index(spec, opts={})
        indexes.create_one(spec, opts)
      end

      def create_indexes(specs)
        indexes.create_many(specs)
      end

      def drop
        database.collections.delete[name]
        native.drop
      end

    end
  end
end end