require 'robe/common/errors'
require 'robe/common/util'
require 'robe/common/model'
require 'robe/common/promise'

# WARNING WARNING WARNING
#
# Use of #get(attr) and #set(attr, value)
# except by internal db model/association
# methods is NOT advised - they are the
# back door by which internal db model
# methods access/set attribute values.
# Use only standard getter/setter methods,
#   e.g. product.recipe, product.recipe=
# Do not use:
#   e.g. product.get(:recipe), product.set(:recipe, recipe)
#
module Robe; module DB
  class Model < Robe::Model
  end
end end

require 'robe/common/db/model/associations'
require 'robe/common/db/model/cache'
require 'robe/common/db/model/csv_io'

# TODO: make more isomorphic?
if RUBY_PLATFORM == 'opal'
  require 'robe/client/db'
else
  require 'robe/server/app'
end

module Robe; module DB
  class Model
    extend Robe::DB::Model::CSV_IO_Methods
    include Robe::DB::Model::Associations
    include Robe::Util

    attr :_id                 # all models should have an id - mongo uses underscore
    alias_method :id, :_id    # because we'll always forget the underscore
    alias_method :id=, :_id=

    def self.cache
      @cache
    end

    def self.cache=(cache)
      # trace __FILE__,  __LINE__, self, __method__, "(#{cache})"
      @cache = cache
    end

    def self.cached?
      !!cache
    end

    def self.db
      @db ||= if RUBY_PLATFORM == 'opal'
        Robe::Client::DB
      else
        Robe::Server::DB
      end
    end

    def self.collection_name
      # TODO: handle module namespacing smarter
      @collection_name ||= self.name.split('::').last.snake_case.pluralize
    end

    def self.table_name
      collection_name
    end

    # Returns a promise whose value is an array of hashes.
    def self.all
      find
    end

    def self.normalize_attrs(hash_from_db)
      {}.tap do |result|
        hash_from_db.each do |attr, value|
          attr = attr.to_sym
          result[attr] = value if attr == :__from_db__ || attrs.include?(attr)
        end
      end
    end

    # WARNING: destructive : destroys all data in db collection
    # and clears cache of any cached class instances.
    def self.drop
      cache.clear(self) if cache
      db.drop(collection_name)
    end
    
    # If the class is cache'd returns an array of models.
    # If the class is not cache'd returns a promise whose value is an array of models.
    def self.find(**filter)
      __method = __method__
      filter[:_id] = filter[:id] if filter[:id]
      if cache
        # trace __FILE__,  __LINE__, self, __method, "(filter: #{filter}) : checking cache"
        cache.find(self, filter)
      else
        # trace __FILE__,  __LINE__, self, __method, "(filter: #{filter}) #{collection_name}"
        db.find(collection_name, filter.stringify_keys).to_promise_then do |raw|
          # trace __FILE__,  __LINE__, self, __method, " : db.find(#{collection_name}, filter: #{filter}) => '#{raw.class}'"
          raw == [raw] unless raw.is_a?(Array)
          raw.compact.map { |hash|
            hash[:__from_db__] = true
            new(**normalize_attrs(hash)) # keyword arg keys must be symbols
          }
        end
      end
    end

    # If on server or the class is cache'd returns a model or nil.
    # If on client and the class is not cache'd returns a promise whose value is nil or a model.
    def self.find_one(**filter)
      __method = __method__
      if cache
        cache.find(self, filter).first
      else
        # trace __FILE__,  __LINE__, self, __method, "(filter: #{filter}) #{collection_name}"
        db.find_one(collection_name, filter.stringify_keys).to_promise_then do |raw|
          # trace __FILE__,  __LINE__, self, __method, "(#{collection_name}, filter: #{filter}) : raw.class=#{raw.class} raw => #{raw}"
          if raw.is_a?(Hash)
            raw[:__from_db__] = true
            new(**normalize_attrs(raw)) # keyword arg keys must be symbols
          elsif raw.nil?
            # trace __FILE__,  __LINE__, self, __method, " : resolved model = NIL"
            nil
          else
            msg = " : unexpected value returned from find #{raw.class}"
            trace __FILE__,  __LINE__, self, __method, msg
            raise DBError, "#{__FILE__}[#{__LINE__}] #{name}##find" + msg
          end
        end
      end
    end

    def self.association_local_attrs
      unless @association_local_attrs
        @association_local_attrs = []
        associations.values.each do |associations|
          associations.each do |association|
            @association_local_attrs << association.local_attr
          end
        end
      end
      @association_local_attrs
    end

    # TODO: handle association intelligently.
    def initialize(**args)
      args[:_id] = args[:id] if args[:id]
      
      if RUBY_PLATFORM == 'opal'
        args = args.symbolize_keys
      end

      # trace __FILE__,  __LINE__, self, __method__, " : args.class=#{args.class} args=#{args}"
      # trace __FILE__,  __LINE__, self, __method__, " : attrs=#{self.class.attrs}"
      @from_db = !!args.delete(:__from_db__)
      @deleted = false

      # set unique id if not already done so
      args[:_id] ||= uuid

      # collate any local_attr in args
      local_attrs = {}
      self.class.association_local_attrs.each do |attr|
        arg = args.delete(attr)
        local_attrs[attr] = arg if arg
      end

      # call super with remaining args
      super(**args)

      # now assign any local_attr
      local_attrs.each do |key, value|
        # use write method to ensure foreign_key set
        send(:"#{key}=", value)
      end

      # trace __FILE__,  __LINE__, self, __method__

      # tidy up associations
      self.class.associations.each do |_type, associations|
        associations.each do | association |
          association.on_initialize(self)
        end
      end

      # trace __FILE__,  __LINE__, self, __method__
    end

    def get(attr, caller = nil)
      # trace __FILE__, __LINE__, self, __method__, "(#{attr}, #{caller.class})"
      unless caller.is_a?(self.class) || caller.class.name.include?('Robe::DB')
        # trace __FILE__, __LINE__, self, __method__, " : failed"
        fail "#{self.class.name}##{__method__}(#{attr}) is only for internal Robe::DB use, try ##{attr}= instead"
      end
      # trace __FILE__, __LINE__, self, __method__, " :  calling super(attr)"
      r = super(attr)
      # trace __FILE__, __LINE__, self, __method__, " :  called super(attr)"
      r
    end

    def set(attr, value, caller = nil)
      # trace __FILE__, __LINE__, self, __method__, "(#{attr}, #{caller.class})"
      unless caller.is_a?(self.class) || caller.class.name.include?('Robe::DB')
        # trace __FILE__, __LINE__, self, __method__, " : failed"
        fail "#{self.class.name}##{__method__}(#{attr}, ...) is only for internal Robe::DB use, not #{caller.class}"
      end
      # trace __FILE__, __LINE__, self, __method__, " :  calling super(attr, value)"
      r = super(attr, value)
      # trace __FILE__, __LINE__, self, __method__, " :  called super(attr, value)"
      r
    end

    def cache
      self.class.cache
    end

    def ==(other)
      other.id == self.id
    end

    def new?
      !exists?
    end

    def exists?
      @from_db
    end

    def deleted?
      @deleted
    end

    # check validity of attributes and associations
    # call block with string detailing any errors
    # don't call block if everything ok
    def invalid?(&_block)
    end

    # If on client and no cache then returns a promise whose value is self.
    # If on server or cache then returns self.
    # Delete this model from database (by id), and
    # if there are has_one or has_many associations
    # then delete them too.
    # The model's deleted? method will return true if deleted.
    # It will be removed from the cache if the latter is active.
    def delete
      self.class.db.delete_with_id(self.class.collection_name, id).to_promise_then do
        @deleted = true
        if cache && !cache.includes?(self.class, id)
          msg = "#{__FILE__}[#{__LINE__}] : #{self.class.name} : expected model with id #{id} to be in cache - cannot delete"
          Robe.logger.error(msg)
          raise DBError, msg
        end
        cache.delete(self) if cache
        results = []
        self.class.has_one_associations.each do |assoc|
          if assoc.owner
            send(assoc.local_attr).to_promise_then do |one|
              results << one.delete
            end
          end
        end
        results.to_promise_when
      end.to_promise_then do
        results = []
        self.class.has_many_associations.each do |assoc|
          if assoc.owner
            assoc_results = []
            results << send(assoc.local_attr).to_promise.to_promise_then do |many|
              many.each do |one|
                # trace __FILE__, __LINE__, self, __method__, " deleting associated : #{one}"
                assoc_results << one.delete
              end
              assoc_results.to_promise_when_on_client
            end
          end
        end
        results.to_promise_when.then do
          self
        end
      end
    end

    # inserts or updates as required
    # ensures associations handled as required for db
    # return a promise whose value is self
    def save
      new? ? insert  : update
    end

    # insert model in database
    # ensures associations handled as required for db
    # TODO: should also insert associations
    # Returns a promise with self as value
    # Only ignore associations if, for instance, reloading db dump
    # and referential integrity can be guaranteed.
    def insert(ignore_associations: false)
      unless new?
        msg = "#{__FILE__}[#{__LINE__}] : #{self.class} : should be new (not loaded from db) - cannot insert"
        Robe.logger.error(msg)
        raise DBError, msg
      end
      self.id = uuid unless id
      if cache && cache.includes?(self.class, id)
        msg = "#{__FILE__}[#{__LINE__}] : #{self.class} : with id #{id} already in cache - cannot insert"
        Robe.logger.error(msg)
        raise DBError, msg
      else
        # TODO: unwind associations if insert fails
        result = (ignore_associations ? nil : save_associations).to_promise_on_client
        result.to_promise_then do
          self.class.db.insert_one(self.class.collection_name, to_db_hash)
        end.to_promise_then do
          @from_db = true
          cache.insert(self) if cache # no filter
          self.to_promise_on_client
        end
      end
    end

    # updates model database
    # ensures associations handled as required for db
    # return a promise whose value is self
    def update
      if exists?
        if id
          if cache && !cache.includes?(self.class, id)
            msg = "#{__FILE__}[#{__LINE__}] : #{model.class} : expected model with id #{id} to be in cache - cannot update"
            Robe.logger.error(msg)
            raise DBError, msg
          else
            # TODO: unwind associations if update fails
            save_associations.to_promise_then do
              self.class.db.update_document_by_id(self.class.collection_name, to_db_hash)
            end.to_promise_then do
              self.to_promise_on_client
            end
          end
        else
          msg = "#{__FILE__}[#{__LINE__}] : #{model.class} : expected model from db to have id set - cannot update"
          Robe.logger.error(msg)
          raise DBError, msg
        end
      else
        msg = "#{__FILE__}[#{__LINE__}] : #{model.class} : cannot update model not loaded from db - it should be inserted"
        Robe.logger.error(msg)
        raise DBError, msg
      end
    end

    # returns a promise whose value is self
    def save_associations
      results = []
      self.class.associations.each do | _type, associations |
        associations.each do |association|
          results << association.save(self)
        end
      end
      results.to_promise_when_on_client.to_promise_then do
        self.to_promise_on_client
      end
    end

    def to_db_hash
      to_h
    end

    def to_h_without_circulars
      result = {}
      to_h.each do |attr, value|
        result[attr] = value unless is_belongs_to_attr?(attr)
      end
      result
    end

    def is_belongs_to_attr?(attr)
      self.class.belongs_to_associations.each do |association|
        return true if association.local_attr == attr
      end
      false
    end

  end
end end