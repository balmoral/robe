require 'robe/common/util'
require 'robe/common/promise'

# NB ******
# to be included in either Robe::Client::DB or Robe::Server::DB
# to support isomorphic DB interface
module Robe; module Shared
  class DB
    module Ops

      ID = '_id'

      module ClassMethods

        # Returns a promise.
        def stats
          op(:database, :stats)
        end

        # Returns a promise.
        def collection_names
          op(:database, :collection_names)
        end

        def create(collection)
          op(collection, :create)
        end

        def drop(collection)
          op(collection, :drop)
        end

        def create_collection(name)
          create(name)
        end

        def drop_collection(name)
          drop(name)
        end

        # Returns a promise.
        # e.g. find(:customers, { code: 'TBD' })
        # e.g. find(:customers, { }code: { '$in' => %w(X Y Z) } } )
        # returns array
        def find(collection, filter = nil, options = nil)
          # trace __FILE__, __LINE__, self, __method__, "(#{collection}, filter: #{filter})"
          filter ||= {}
          filter = filter.stringify_keys
          # trace __FILE__, __LINE__, self, __method__, " : filter=#{filter} options=#{options}"
          options ||= {}
          options = options.stringify_keys
          # trace __FILE__, __LINE__, self, __method__, " : filter=#{filter} options=#{options}"
          op(collection, :find, filter, options)
        end

        # Returns a promise.
        # e.g. find_one(:customers, code: 'TBD')
        # return first element in find result, or nil
        def find_one(collection, filter, options = nil)
          filter = (filter || {}).stringify_keys
          options = (options || {}).stringify_keys
          # trace __FILE__, __LINE__, self, __method__, "(#{collection}, filter: #{filter})"
          op(collection, :find, filter, options).to_promise_then do |many|
            many.is_a?(Array) ? many.first : nil
          end
        end

        # Returns a promise.
        # e.g. insert(:customers, customer)
        def insert(collection, document)
          op(collection, :insert_one, document)
        end

        alias_method :insert_one, :insert

        # Returns a promise.
        # # e.g. insert_many(:customers, customers)
        def insert_many(collection, documents)
          op(collection, :insert_many, documents)
        end

        # Returns a promise.
        # e.g. update_one(:customers, { 'name' => 'XYZ' }, { '$set' => { name' => '' } }, { upsert: false })
        def update_one(collection, filter, update, options = nil)
          op(collection, :update_one, filter.stringify_keys, update.stringify_keys, options ? options.stringify_keys : {})
        end

        # Returns a promise.
        # e.g. update_many(:customers, nil, rename: { 'origin_code' => 'action_code' } )
        def update_many(collection, filter, update, options = nil)
          op(collection, :update_many, filter ? filter.stringify_keys : nil, update.stringify_keys, options ? options.stringify_keys : nil)
        end

        # Update (or upsert) a complete document using its ID as filter.
        # If upsert is true document will be be inserted/created if is doesn't yet exist (by ID).
        # If the given document does not have an ID set and upsert is true, it will be given a new uuid.
        # If the given document does not have an ID set and upsert is false, an error will be generated.
        # Returns a promise.
        def update_document_by_id(collection, document, upsert: false)
          document = document.to_h.stringify_keys
          id = document[ID]
          unless id
            if upsert
              document[ID] = Robe::Util.uuid
            else
              raise DBError, "#{self.name}###{__method__} : no id set in document to update"
            end
          end
          update_one(collection,
            { ID => id },
            { '$set' => document },
            { upsert: upsert }
          )
        end

        # DEPRECATED - models must handle this at higher level
        # but keep for reference of bulk_write stuff.
        #
        # Updates (inserts/updates) documents which are associated by
        # `local_key_field` to an owner identified by `owner_key_value`.
        #
        # Expects the local key field value(s) in the given associates
        # to be set by the caller. An error (via return promise) occurs
        # if not done so.
        #
        # Deletes any documents in the collection whose ID's are
        # not in the given associates' ids, then upserts the given associates.
        #
        # WARNING: not atomic and no rollback supported.
        #
        # @param [String, Symbol] collection The name of the collection.
        # @param [String, Symbol] local_key_field The key field used in documents in the given collection.
        # @param [Object] owner_key_value The foreign key value of the owner used as local key in associates.
        # @param [Array<Hash>] associates The associated documents to upsert.
        #
        # @return [Robe::Promise] The value of the promise is unspecified.
        def upsert_associates(collection, local_key_field, owner_key_value, associates)
          trace __FILE__, __LINE__, self, __method__, " : associates.class=#{associates.class}"
          associates = associates.map(&:stringify_keys)
          local_key_field = local_key_field.to_s
          # check all associates have appropriate owner key
          associates.each do |associate|
            unless associate[local_key_field] == owner_key_value
              return Robe::Promise.error("#{__method__}(#{collection}, #{local_key_field}, #{owner_key_value}, ...) : associates must have local_key to to owner_key")
            end
          end
          update_ids = associates.map{|e| e[ID]}.compact
          # delete any associates which are not in given associates
          delete_filter = {'$and' => [{local_key_field => owner_key_value}, {ID => {'$nin' => update_ids}}]}
          ops = []
          ops << {
            'deleteMany' => {
              'filter' => delete_filter
            }
          }
          associates.each do |associate|
            ops << {
              'updateOne' => {
                'filter' =>  { ID => associate.id },
                'update' => associate,
                'upsert' => true
              }
            }
          end
          bulk_write(collection, ops)
        end

        # Returns a promise.
        # e.g. delete_with_id(:customers, id )
        def delete_with_id(collection, id)
          delete_one(collection, { ID => id })
        end

        # Returns a promise.
        # e.g. delete_with_ids(:customers, ids)
        def delete_with_ids(collection, ids)
          delete_many(collection, { ID => { '$in' => ids } })
        end

        # Returns a promise.
        # e.g. delete_one(:customers, { '_id' => something.id })
        def delete_one(collection, filter)
          op(collection, :delete_one, filter.stringify_keys)
        end

        # Returns a promise.
        # e.g. delete_many(:customers, { 'date' => { '$lt' => '2070817'} })
        # If filter is not given all documents in collection will be deleted!
        def delete_many(collection, filter = nil)
          op(collection, :delete_many, filter ? filter.stringify_keys : nil)
        end

        # Performs a bulk write of given operations.
        # Returns a promise.
        def bulk_write(collection, ops)
          op(collection, :bulk_write, ops)
        end

      end

      def self.included(base)
         base.extend(ClassMethods)
      end
    end
  end
end end