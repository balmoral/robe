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
require 'robe/common/util/core_ext'
require 'robe/common/util/ymd'

module Robe
  class Model

    CSV_COMMA_SUB = '~COMMA~' # to substitute for commas in string values
    CSV_TAB_SUB = '~TAB~' # to substitute for tabs in string values
    CSV_NL_SUB = '~NL~' # to substitute for new lines in string values
    CSV_CR_SUB = '~CR~' # to substitute for carriage returns in string values

    ATTR_SPEC_SINGLE_TYPE = 0
    ATTR_SPEC_MULTI_TYPE  = 1
    ATTR_SPEC_DEFAULT     = 2
    ATTR_SPEC_NIL         = 3
    ATTR_SPEC_READ        = 4
    ATTR_SPEC_WRITE       = 5
    ATTR_SPEC_INSIST      = 6
    ATTR_SPEC_FIX_LENGTH  = 7
    ATTR_SPEC_VAR_LENGTH  = 8
    ATTR_SPEC_ENUM        = 9
    ATTR_SPEC_REGEXP      = 10

    # subclass may override
    def self.mutable?
      true
    end

    def self.immutable?
      !mutable?
    end

    # lazy initialize - pull in superclass attrs if relevant
    def self.attrs
      @attrs ||= superclass < Robe::Model && superclass.respond_to?(:attrs) ? superclass.send(:attrs).dup : []
    end

    def self.attr_specs
      @attr_specs ||= superclass < Robe::Model && superclass.respond_to?(:attr_specs) ? superclass.send(:attr_specs).dup : {}
    end

    def self.attr_spec(attr)
      attr_specs[attr] ||= []
    end
    
    def self.read_attrs
      attrs
    end

    def self.write_attrs
      @write_attrs ||= mutable? ? attrs.map{|attr| :"#{attr}="} : []
    end

    # TODO: refactor read:, write:, coerce, etc
    # if there are write coercions does validation happen before or after coercion?
    #
    # TODO: update these docs to ensure accuracy!
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
    # or
    #
    #   class User < Robe::Model
    #     attr: name, type: String, write: ->(value) {value.to_s}, insist: ->(value) { value && value.size >= 4 }
    #     attr: password, type: String, write: ->(value) {value.to_s}, insist: ->(value) { value && value.size >= 8 }
    #   end
    #
    # or
    #
    #   class User < Robe::Model
    #     attr: name, **name_spec
    #     attr: password, class: String, coerce: ->(value) {value.to_s}, insist: ->(value) { value && value.size >= 8 }
    #
    #     def self.name_spec
    #       {
    #         type: [TrueClass, FalseClass], # or :boolean
    #         read: ->(value) {
    #           value == 'T' ? true : false
    #         },
    #         write: ->(value) {
    #           value == TrueClass ? 'T' : 'F'
    #         },
    #         insist: ->(value) {
    #           value == TrueClass || value == FalseClass
    #         }
    #       }
    #     end
    #   end
    #
    #   Attributes with one class of String, Integer, Float, Time, Date
    #   will be provided with default write coercion of to_s, to_i, to_f, Time.parse, Date.parse
    #   if not otherwise specified.
    #
    #   'insist' proc should return true if successful, or a String containing an error message.
    #   'read' and 'write' coercion should be a proc or a hash which maps values
    #
    #   Other attr specs are:
    #     default: 'xyz'          # a default value if nil is given for attribute
    #     length: 6 | 4..10       # String only - fixed length or length range
    #     enum: %w(T F) | 4..10   # all classes insist value is one of given enumerable
    #     nil: true/false         # DEFAULT IS FALSE
    #
    def self.attr(*args)
      if (args[0].is_a?(Symbol) || args[0].is_a?(String)) && args[1].is_a?(Hash)
        attr = args[0].to_sym
        unless attr?(attr)
          attrs << attr
          # readers
          define_method(attr) do
            @hash[attr]
          end
          if arg_spec = args[1]
            spec = attr_spec(attr)
            arg_spec.each do |key, value|
              index = case key
                when :type
                  type = value
                  if type == :boolean
                    ATTR_SPEC_SINGLE_TYPE
                  elsif type == :ymd || type == Ymd
                    value = :ymd
                    ATTR_SPEC_SINGLE_TYPE
                  elsif type.is_a?(Class)
                    ATTR_SPEC_SINGLE_TYPE
                  elsif type.is_a?(Enumerable)
                    value = value.to_a
                    value.each do |e|
                      unless e.is_a?(Class)
                        raise ModelError, "#{self.name}##attr(#{args}) : each value of #{key} must be a Class"
                      end
                    end
                    ATTR_SPEC_MULTI_TYPE
                  else
                    raise ModelError, "#{self.name}##attr(#{args}) : value of #{key} must be a Class or Array of Class"
                  end
                when :default
                  ATTR_SPEC_DEFAULT
                when :read, :write
                  unless value.is_a?(Proc) || value.is_a?(Hash)
                    raise ModelError, "#{self.name}##attr(#{args}) : value of #{key} must be a Proc or Hash to coerce/map values"
                  end
                  key == :read ? ATTR_SPEC_READ : ATTR_SPEC_WRITE
                when :insist
                  unless value.is_a?(Proc)
                    raise ModelError, "#{self.name}##attr(#{args}) : value of #{key} must be a Proc"
                  end
                  ATTR_SPEC_INSIST
                when :nil
                  unless value == true || value == false
                    raise ModelError, "#{self.name}##attr(#{args}) : value of #{key} spec must be true or false"
                  end
                  ATTR_SPEC_NIL
                when :enum
                  unless value.is_a?(Enumerable)
                    raise ModelError, "#{self.name}##attr(#{args}) : value of #{key} must be an Enumerable, e.g. Array or Range"
                  end
                  ATTR_SPEC_ENUM
                when :regexp
                  unless value.is_a?(Regexp)
                    raise ModelError, "#{self.name}##attr(#{args}) : value of #{key} must be an Regexp"
                  end
                  unless arg_spec[:type] == String
                    raise ModelError, "#{self.name}##attr(#{args}) : type must be String to specify regexp"
                  end
                  ATTR_SPEC_REGEXP
                when :length
                  if value.is_a?(Integer)
                    unless value > 0
                      raise ModelError, "#{self.name}##attr(#{args}) : value of #{key} must be greater than 0"
                    end
                    ATTR_SPEC_FIX_LENGTH
                  elsif (value.is_a?(Range) && value.first.is_a?(Integer) && value.last.is_a?(Integer))
                    unless value.first >= 0 && value.last > 0
                      raise ModelError, "#{self.name}##attr(#{args}) : values of #{key} range must be greater than or equal to 0"
                    end
                    ATTR_SPEC_VAR_LENGTH
                  else
                    raise ModelError, "#{self.name}##attr(#{args}) : value of #{key} must be an Integer or Range of integers"
                  end
                else
                  raise ModelError, "#{self.name}##attr(#{args}) : spec key must be one of :class, :coerce, :ensure, not #{key}"
              end
              spec[index] = value
            end
            if spec[ATTR_SPEC_NIL].nil?
              spec[ATTR_SPEC_NIL] = false
            end
            if (type = spec[ATTR_SPEC_SINGLE_TYPE])
              spec[ATTR_SPEC_READ] ||= case
                when type == :boolean
                  ->(value) {
                      if value.is_a?(Numeric)
                        value != 0
                      else
                        c = value.to_s[0]
                        c == 'T' || c == 't' || c == 'Y' || c == 'y'
                      end
                  }
                when type == :ymd || type == Ymd
                  ->(value) {
                    value ? Ymd.try_convert(value) : nil
                  }
                when type == String
                  ->(value) {
                    value.to_s
                  }
                when type == Integer
                  ->(value) {
                    value.respond_to?(:to_i) ? value.to_i : value
                  }
                when type == Float
                  ->(value) {
                    value.respond_to?(:to_f) ? value.to_f : value
                  }
                when type == Time
                  ->(value) {
                    value.is_a?(String) ? Time.parse(value) : value
                  }
                when type == Date
                  ->(value) {
                    value.is_a?(String) ? Date.parse(value) : value
                  }
                else
                  nil
              end
              spec[ATTR_SPEC_WRITE] ||= case
                when type == :boolean
                  ->(value) {
                    value.to_s[0].upcase # true becomes 'T, false becomes 'F'
                  }
                when type == :ymd || type == Ymd
                  ->(value) {
                    value ? Ymd.convert(value).ymd : ''
                  }
                else
                  nil
              end
            end
          end
          if mutable?
            # writer #attr
            if arg_spec
              define_method(:"#{attr}=") do |value|
                @hash[attr] = __attr_read_value(attr, value)
              end
            else
              define_method(:"#{attr}=") do |value|
                @hash[attr] = value
              end
            end
          end
        end
      else
        # puts "#{__FILE__}[#{__LINE__}] #{self.class.name}##{__method__}(#{args})"
        args.each do |attr|
          attr(attr, type: Object, nil: true)
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
      new(**JSON.parse(s).symbolize_keys)
    end

    def initialize(**args)
      @hash = {}
      args.each do |attr, value|
        attr = attr.to_sym
        must_be_attr!(attr)
        @hash[attr] = __attr_read_value(attr, value)
      end
      attrs.each do |attr|
        unless args.key?(attr)
          @hash[attr] = __attr_read_value(attr, nil)
        end
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
      # spec check must be done here
      @hash = merge_hash(*args, spec: true)
      # trace __FILE__, __LINE__, self, __method__, " : @hash = #{@hash}"
      self
    end

    # Returns a new instance of the model with its attributes merged
    # with the arguments. Keyword arguments can be used, or single model
    # or splat of models (or anything that responds to :to_h)
    def merge(*args)
      # spec check will be done in #initialize
      self.class.new(merge_hash(*args, spec: false))
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
      attr = attr.to_sym
      must_be_attr!(attr)
      @hash[attr] = __attr_read_value(attr, value)
    end

    def values(*attr_names)
      attr_names.map { |n| self[n] }
    end

    # Returns model attribute values as CSV string.
    # If attrs is given it will determine which attributes and their order.
    # Commas, newlines, carriage returns and tabs in values will be substituted
    # with given substitutes or Robe::Model defaults.
    def to_csv(attrs: nil, comma_sub: nil, cr_sub: nil, nl_sub: nil, tab_sub: nil)
      attrs ||= self.attrs
      comma_sub ||= CSV_COMMA_SUB
      nl_sub ||= CSV_NL_SUB
      cr_sub ||= CSV_CR_SUB
      # tab_sub ||= CSV_TAB_SUB
      [].tap { |result|
        attrs.each do |attr|
          value = @hash[attr]
          value = __attr_write_value(attr, value)
          value = value.to_s.gsub(',', comma_sub)
          value = value.gsub('\n', nl_sub)
          value = value.gsub('\r', cr_sub)
          value = value.gsub('\t', tab_sub) if tab_sub
          result << value
        end
      }.join(',')
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

    # returns attributes in a hash - dup'd from internal hash
    def to_h
      @hash.dup
    end

    # Returns a hash resulting from merging attributes in argument(s)
    # with this model's attributes hash. Keyword arguments can be used,
    # or a single hash, or a single model, or a splat of hashes
    # or a splat of models.
    def merge_hash(*args, spec: true)
      # user may want to merge non-attr stuff,
      # so no check on valid attributes
      result = to_h
      args.each do |arg|
        arg.to_h.each do |attr, value|
          result[attr] = if spec
            must_be_attr!(attr)
            __attr_read_value(attr, value)
          else
            value
          end
        end
      end
      args.reduce(to_h) do |memo, arg|
        memo.merge(arg.to_h)
      end
    end

    alias_method :to_hash, :to_h

    def to_json
      {}.tap { |h|
        to_h_without_circulars.each do |attr, value|
          h[attr] = __attr_write_value(attr, value)
        end
      }.to_json
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


    protected

    # Coerce an attribute value to a value appropriate
    # for csv, json or database.
    # Returns the coerced value.
    def __attr_write_value(attr, value)
      attr_spec = self.class.attr_spec(attr)
      if attr_spec.empty?
        return value
      end
      if (coerce = attr_spec[ATTR_SPEC_WRITE])
        # NB [] works for Hash and Proc
        coerce[value]
      else
        value
      end
    end

    # Coerce a value to be assigned to an attribute
    # into appropriate type and value. The value may
    # come from csv, json, database or application.
    # Returns the coerced value.
    def __attr_read_value(attr, value)
      attr_spec = self.class.attr_spec(attr)
      if attr_spec.empty?
        return value
      end
      unless value
        value = attr_spec[ATTR_SPEC_DEFAULT]
        value = value.call if value.is_a?(Proc)
      end
      if (coerce = attr_spec[ATTR_SPEC_READ])
        # NB [] works for Hash and Proc
        value = coerce[value]
      end
      unless (nil_spec = attr_spec[ATTR_SPEC_NIL]).nil?
        if nil_spec == false && value.nil?
          raise ModelError, "#{self.class.name}##{attr}=(#{value}) : value #{value} must not be nil"
        end
      end
      unless value.nil?
        if type = attr_spec[ATTR_SPEC_SINGLE_TYPE]
          if type == :boolean
            unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
              raise ModelError, "#{self.class.name}##{attr}=(#{value}) : value #{value} must be TrueClass or FalseClass not #{value.class}"
            end
          elsif type == :ymd || type == Ymd
            unless value.is_a?(Ymd)
              raise ModelError, "#{self.class.name}##{attr}=(#{value}) : value #{value} must be Ymd not #{value.class}"
            end
          else
            unless value.is_a?(type)
              raise ModelError, "#{self.class.name}##{attr}=(#{value}) : value #{value} must be type #{type} not #{value.class}"
            end
          end
        elsif types = attr_spec[ATTR_SPEC_MULTI_TYPE]
          unless types.include?(value.class)
            raise ModelError, "#{self.class.name}##{attr}=(#{value}) : value #{value} must be type #{types.join(' or ')} not #{value.class}"
          end
        end
        if length = attr_spec[ATTR_SPEC_FIX_LENGTH]
          unless value.length == length
            raise ModelError, "#{self.class.name}##{attr}=(#{value}) : value #{value} must be fixed length of #{length} not #{value.length}"
          end
        elsif length = attr_spec[ATTR_SPEC_VAR_LENGTH]
          unless length.include?(value.length)
            raise ModelError, "#{self.class.name}##{attr}=(#{value}) : value #{value} must be length in range #{length} not #{value.length}"
          end
        end
        if insist = attr_spec[ATTR_SPEC_INSIST]
          unless true == insist.call(value)
            raise ModelError, "#{self.class.name}##{attr}=(#{value}) : value #{value} insist failure : #{result}"
          end
        end
        if regexp = attr_spec[ATTR_SPEC_REGEXP]
          unless value =~ regexp
            raise ModelError, "#{self.class.name}##{attr}=(#{value}) : String value '#{value}' does not match regexp #{regexp}"
          end
        end
        if enum = attr_spec[ATTR_SPEC_ENUM]
          unless enum.include?(value)
            raise ModelError, "#{self.class.name}##{attr}=(#{value}) : value '#{value}' not included in #{enum}"
          end
        end
      end
      value
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

