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

# TODO: make more isomorphic?
if RUBY_PLATFORM == 'opal'
  require 'robe/client/db'
else
  require 'robe/server/app'
end

module Robe; module DB
  class Model
    include Robe::DB::Model::Associations
    include Robe::Util

    attr :_id                 # all models should have an id - mongo uses underscore
    alias_method :id, :_id    # because we'll always forget the underscore
    alias_method :id=, :_id=

    def self.cache
      @cache
    end

    def self.cache=(cache)
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
          result[attr] = value if attrs.include?(attr)
        end
      end
    end

    # If the class is cache'd returns an array of models.
    # If the class is not cache'd returns a promise whose value is an array of models.
    def self.find(**filter)
      __method = __method__
      if cache
        # trace __FILE__,  __LINE__, self, __method, "(filter: #{filter}) : checking cache"
        cache.find(self, filter)
      else
        # trace __FILE__,  __LINE__, self, __method, "(filter: #{filter}) #{collection_name}"
        db.find(collection_name, filter.stringify_keys).then do |raw|
          # trace __FILE__,  __LINE__, self, __method, " : db.find(#{collection_name}, filter: #{filter}) => '#{raw.class}'"
          raw == [raw] unless raw.is_a?(Array)
          raw.compact.map { |hash|
            hash[:__from_db__] = true
            new(normalize_attrs(hash)) # keyword arg keys must be symbols
          }
        end
      end
    end

    # If the class is cache'd returns a model or nil.
    # If the class is not cache'd returns a promise whose value is nil or a model.
    def self.find_one(**filter)
      __method = __method__
      if cache
        cache.find(self, filter).first
      else
        trace __FILE__,  __LINE__, self, __method, "(filter: #{filter}) #{collection_name}"
        db.find_one(collection_name, filter.stringify_keys).then do |raw|
          # trace __FILE__,  __LINE__, self, __method, "(#{collection_name}, filter: #{filter}) : raw.class=#{raw.class} raw => #{raw}"
          if Hash === raw
            raw[:__from_db__] = true
            new(normalize_attrs(raw)) # keyword arg keys must be symbols
          elsif raw.nil?
            trace __FILE__,  __LINE__, self, __method, " : resolved model = NIL"
            nil
          else
            msg = " : unexpected value returned from find #{raw.class}"
            trace __FILE__,  __LINE__, self, __method, msg
            Robe::Promise.error("#{__FILE__}[#{__LINE__}] #{name}##find" + msg)
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
      super **args

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
        fail "#{self.class.name}##{__method__}(#{attr}) is only for internal Robe::DB use, not #{caller.class}"
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

    # Returns a promise whose value is self.
    # Delete this model from database (by id), and
    # if there are has_one or has_many associations
    # then delete them too.
    # The model's deleted? method will return true if deleted.
    # It will be removed from the cache if the latter is active.
    def delete
      self.class.db.delete_with_id(self.class.collection_name, id).then do
        @deleted = true
        if cache && !cache.includes?(self.class, id)
          msg = " : #{self.class.name} : expected model with id #{id} to be in cache - cannot delete"
          trace __FILE__, __LINE__, self, __method__, msg
          fail "#{__FILE__}[#{__LINE__}]#{msg}"
        end
        cache.delete(self) if cache
        promises = []
        self.class.has_one_associations.each do |assoc|
          if assoc.owner
            if (one = send(assoc.local_attr))
              promises << one.delete
            end
          end
        end
        Robe::Promise.when(*promises).then do
          self
        end
      end.then do
        promises = []
        self.class.has_many_associations.each do |assoc|
          if assoc.owner
            if (many = send(assoc.local_attr))
              many.each do |one|
                promises << one.delete
              end
            end
          end
        end
        Robe::Promise.when(*promises) do
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
    def insert
      unless new?
        fail("#{__FILE__},  #{__LINE__} : #{self.class} : should be new (not loaded from db) - cannot insert")
      end
      self.id = uuid unless id
      if cache && cache.includes?(self.class, id)
        fail("#{__FILE__},  #{__LINE__} : #{self.class} : with id #{id} already in cache - cannot insert")
      else
        # TODO: unwind associations if insert fails
        save_associations.then do
          self.class.db.insert_one(self.class.collection_name, to_db_hash)
        end.then do
          @from_db = true
          cache.insert(self) # no filter
          Robe::Promise.value(self)
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
            fail("#{__FILE__},  #{__LINE__} : #{model.class} : expected model with id #{id} to be in cache - cannot update")
          else
            # TODO: unwind associations if update fails
            save_associations.then do
              self.class.db.update_document_by_id(self.class.collection_name, to_db_hash)
            end.then do
              Robe::Promise.value(self)
            end
          end
        else
          fail("#{__FILE__},  #{__LINE__} : #{model.class} : expected model from db to have id set - cannot update")
        end
      else
        fail("#{__FILE__},  #{__LINE__} : #{model.class} : cannot update model not loaded from db - it should be inserted")
      end
    end

    # returns a promise whose value is self
    def save_associations
      promises = []
      self.class.associations.each do | _type, associations |
        associations.each do |association|
          promises << association.save(self)
        end
      end
      Robe::Promise.when(*promises).then do
        Robe::Promise.value(self)
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