# Simple model definition with a few convenience methods.
#
# Creates get/set methods for each attribute.
#
# #initialize will call #after_initialize
#
# TODO: extend so that hash of attributes, types
# default values, etc can be provided.
#

require 'json'
require 'robe/common/errors'

module Robe
  class Model

    # subclass may override
    def self.mutable?
      true
    end

    def self.immutable?
      !mutable?
    end

    # lazy initialize - pull in superclass attrs if relevant
    def self.attrs
      @attrs ||= superclass < Robe::Model && superclass.respond_to?(__method__) ? superclass.attrs.dup : []
    end

    def self.read_attrs
      attrs
    end

    def self.write_attrs
      @write_attrs ||= mutable? ? attrs.map{|attr| :"#{attr}="} : []
    end

    # DSL method, e.g.
    #
    #   class User < Robe::Model
    #     attr: name
    #     attr: password
    #   end
    #
    # or
    #
    #   class User < Robe::Model
    #     attr: name, password
    #   end
    #
    #
    def self.attr(*args)
      # puts "#{__FILE__}[#{__LINE__}] #{self.class.name}##{__method__}(#{args})"
      args.each do |attr|
        attr = attr.to_sym
        unless attr?(attr)
          attrs << attr
          # readers
          define_method(attr) do
            @hash[attr]
          end
          if mutable?
            # writer #attr=
            define_method(:"#{attr}=") do |value|
              @hash[attr] = value
            end
          end
        end
      end
      attrs_defined
    end

    def self.read_state_methods
      [:[], :get, :==, :values, :to_csv, :to_json, :to_h, :to_hash, :csv_head, :dup, :to_s, :merge_hash]
    end

    # methods which require a store to duplicate the state before calling the method
    def self.reduce_dup_methods
      [:[]=, :set, :merge!]
    end

    # methods which may return a new mutated version/instance of the model class
    def self.reduce_mutate_methods
      [:merge, :mutate!]
    end

    # hook to allow subclasses to do something after attr
    def self.attrs_defined
      self
    end

    def self.attr?(name)
      attrs.include?(name.to_sym)
    end

    def self.csv_head
      attrs.join(',')
    end

    def self.from_hash(hash)
      new(**hash)
    end

    def self.from_json(s)
      new(**JSON.parse(s))
    end

    def initialize(**args)
      @hash = {}
      args.each do |key, value|
        key = key.to_sym
        must_be_attr!(key)
        @hash[key] = value
      end
      after_initialize
    end

    # stub for subclasses to do their thing
    def after_initialize
    end

    # Returns a new and mutated version of the model.
    # Keys should be defined attributes of the model.
    # Any keyword args are merged with the receiver's attributes.
    # See #merge for further argument options.
    # If a block is given, the block will be called with the new version.
    # The new version is then returned.
    def mutate!(*args, &block)
      mutation = merge(*args)
      block.call(mutation) if block
      # trace __FILE__, __LINE__, self, __method__, " : mutation = #{mutation.to_h}"
      mutation
    end

    # Merge (without mutation) the arguments into the attributes of the model.
    # See #merge for further argument options.
    def merge!(*args)
      fail "instances of #{self.class.name} are not mutable" unless mutable?
      @hash = merge_hash(*args)
      # trace __FILE__, __LINE__, self, __method__, " : @hash = #{@hash}"
      self
    end

    # Returns a new instance of the model with its attributes merged
    # with the arguments. Keyword arguments can be used, or single model
    # or splat of models (or anything that responds to :to_h)
    def merge(*args)
      self.class.new(merge_hash(*args))
    end

    def attr?(name)
      self.class.attr?(name)
    end

    def ==(other)
      return false unless self.class == other.class
      return false unless @hash.keys == other.to_h.keys
      @hash.each do |attr, value|
        return false unless value == other[attr]
      end
      true
    end

    # model[attr] is alias of model.send(attr), i.e. model.attr
    def [](attr)
      send(attr)
    end

    # model[attr] = value is alias of model.attr = value
    def []=(attr, value)
      send(:"#{attr}=", value)
    end

    # allows subclasses to override read accessor and still read underlying hash
    def get(attr)
      @hash[attr.to_sym]
    end

    # allows subclasses to override write accessor and still modify underlying hash
    def set(attr, value)
      must_be_mutable!
      must_be_attr!(attr)
      @hash[attr.to_sym] = value
    end

    def values(*attr_names)
      attr_names.map { |n| self[n] }
    end

    def to_csv
      @hash.values.join(',')
    end

    def clone
      c = super
      c.instance_variable_set(:'@hash', @hash.dup)
      c
    end

    def dup
      d = super
      d.instance_variable_set(:'@hash', @hash.dup)
      d
    end

    # TODO: consider whether immutables should dup @hash
    def to_h
      mutable? ? @hash : @hash.dup
    end

    # Returns a hash resulting from merging attributes in argument(s)
    # with this model's attributes hash. Keyword arguments can be used,
    # or a single hash, or a single model, or a splat of hashes
    # or a splat of models.
    def merge_hash(*args)
      # user may want to merge non-attr stuff,
      # so no check on valid attributes
      args.reduce(to_h) do |memo, arg|
        memo.merge(arg.to_h)
      end
    end

    alias_method :to_hash, :to_h

    def to_json
      to_h_without_circulars.to_json
    end

    # stub for subclasses to remove any circular reference for to_json
    def to_h_without_circulars
      @hash
    end

    def to_s
      "#{self.class.name} : #{@hash}"
    end

    def mutable?
      self.class.mutable?
    end

    def attrs
      self.class.attrs
    end

    def csv_head
      self.class.csv_head
    end
    
    def must_be_attrs!(*attrs)
      attrs.each { |attr| must_be_attr!(attr) }
    end
    
    def must_be_attr!(attr)
      unless attr?(attr)
        raise ArgumentError, "#{attr} is not an attribute of #{self.class.name}" 
      end
    end
    
    def must_be_mutable!
      fail "instances of #{self.class.name} are not mutable" unless mutable?
    end
    
  end

  class Mutable < Robe::Model
  end

  class Immutable < Robe::Model

    def self.mutable?
      false
    end

    # Returns a new instances with merged attributes
    def merge!(*args)
      merge(*args)
    end

  end
end

