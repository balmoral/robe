require 'robe/common/promise'

module Robe; module DB; class Model
  class Cache

    attr_reader :scope
    attr_reader :loaded

    # A cache is transient - it  is only active within a 'use' block.
    #
    # It can be re-used as required.
    #
    # Each re-use reloads the cache from the database.
    #
    # While a cache is in use, the cached model classes have their
    # cache set to the in-use cache.
    #
    # After a cache goes out of use, it resets the affected model class
    # caches to their previous value.
    #
    # Example:
    #   Cache.new(Product, Recipe, Ingredient, Order => { date: { '$gte' => Date.today }}).use do |cache, errors|
    #     if errors
    #       app.set_errors(errors)
    #     else
    #       puts "cache contains #{cache.products.size} products"
    #       ...
    #     end
    #   end
    #
    # A singleton method will be defined in the cache for each model class's collection name.
    # Example:
    #     cache.products.each { |product| ... }
    #
    # Robe::DB::Models are cache aware. The cache will set the
    # model class cache to itself on successful loading of model class.
    # The model class will then route any finds through the cache.
    # Insert, update and delete of models will be write through to
    # the database (and return promises), and will update the cache
    # as required.
    #
    # N.B. there is only one cache active per model class at any time,
    # hence the requirement to always access the cache in a use block.
    #
    # In general you will want to load all associated classes to ensure
    # full referential integrity WITHIN the cache.
    #
    # The result of DB::Model.find's and association methods will be promises
    # if the model class is not cached. If the model class is cached then the
    # result of find's will be not be wrapped in a promise.
    #
    def initialize(*classes_and_filters)
      # trace __FILE__, __LINE__, self, __method__, " : classes_and_filters=#{classes_and_filters}"
      init_vars
      init_scope(*classes_and_filters)
      init_methods
    end

    # Returns promise with self as value when all scoped classes loaded.
    def load(&callback)
      promises = []
      scope.each do |model_class, filter|
        # unless model_class.cache.nil?
        #   fail "#{model_class} is already using a cache of type #{model_class.cache.class}"
        # end
        @prior_caches[model_class] = model_class.cache
        model_class.cache = nil # we want the class to go to db
        filter = {} if filter.nil? || filter == :all
        trace __FILE__, __LINE__, self, __method__, " : #{model_class} : filter = #{filter}"
        promises << model_class.find(**filter.symbolize_keys).then do |result|
          callback.call(loaded: model_class) if callback
          result = result.to_a
          trace __FILE__, __LINE__, self, __method__, " : #{model_class} : filter = #{filter} : result.size = #{result.size}"
          @models[model_class] = result
          model_class.cache = self # from now on we want the class to go through self
        end
      end
      promises.to_promise_when_on_client.then do
        trace __FILE__, __LINE__, self, __method__, " : ALL #{promises.size} CACHE CLASSES LOADED"
        self
      end
    end

    def stop
      model_classes.each do |model_class|
        if model_class.cache == self
          model_class.cache = @prior_caches[model_class]
        end
      end
      init_vars
    end

    def model_classes
      @models.keys
    end

    def models(model_class = nil)
      model_class ? @models[model_class] : @models
    end

    def find(model_class, **filter)
      class_models = models(model_class) || []
      if class_models.empty?
        class_models
      else
        procs = compile_filter(filter)
        class_models.select { |model|
          procs.reduce(true) { |memo, proc|
            memo && proc.call(model)
          }
        }
      end
    end

    def find_id(model_class, id)
      @models[model_class].find { |candidate| candidate.id == id}
    end

    def includes?(model_class, id)
      !!find_id(model_class, id)
    end

    # expected to be called by a Robe::DB::Model instance
    def insert(model)
      models = @models[model.class]
      if models.detect { |candidate| candidate.id == model.id }
        fail "#{self.class.name}##{__method__} : model #{model.class} id #{model.id} already in cache"
      end
      models << model
      self
    end

    # expected to be called by a Robe::DB::Model instance
    def delete(model)
      @models[model.class].delete_if { |candidate| candidate.id == model.id }
      self
    end

    def clear(model_class)
      @models[model_class] = []
    end

    private

    def init_vars
      @models = {}
      @prior_caches = {}
      @use_block = nil
    end

    def init_scope(*classes_and_filters)
      @scope = {}
      classes_and_filters.each { |arg|
        if arg.is_a?(Hash)
          arg.each do |c, f|
            @scope[c] = f
          end
        elsif arg < Robe::DB::Model
          @scope[arg] = {}
        else
          fail "cache scope must be a subclass of Robe::DB::Model - not a #{arg}"
        end
      }
    end

    def compile_filter(filter)
      # trace __FILE__, __LINE__, self, __method__, "(#{filter})"
      procs = []
      filter.each do |lhs, rhs|
        if [:and, 'and', '$and'].include?(lhs)
          procs << ->(model) {
            rhs.reduce(true) { |m1, f1|
              m1 && compile_filter(f1).reduce(true) { |m2, f2|
                m2 && f2.call(model)
              }
            }
          }
        elsif [:or, 'or', '$or'].include?(lhs)
          procs << ->(model) {
            rhs.reduce(true) { |m1, inner_filter|
              memo && compile_filter(inner_filter).call(model)
            }
          }
        else
          # not an known operator, so is op an attribute of model?
          # such as filter of form { code: 'XYZ' } or { code: { eq: 'XYZ'} }
          unless lhs.is_a?(String) || lhs.is_a?(Symbol)
            fail "expected string or symbol as attribute of model class - got '#{lhs}'"
          end
          attr = lhs.to_sym
          if rhs.is_a?(Hash)
            unless rhs.size == 1
              fail "expected hash with one entry whose key is an operator (eg $eq, $gte, $in, ...) - got #{rhs}"
            end
            op = compile_op(rhs.keys.first)
            unless op
              fail "expected hash with one entry whose key is an operator ($eq, $gte, $in, ...) - got #{rhs.keys.first}"
            end
            operand = rhs.values.first
            procs << ->(model) {
              unless model.respond_to?(attr)
                fail "'#{attr}' is not an attribute or method of #{model.class}"
              end
              if op == :include? || op == :exclude?
                unless operand.respond_to?(op)
                  fail "#{model.class} attribute '#{attr}' op '#{op}': operand of type #{operand.class} must respond to :include? or :exclude?"
                end
                operand.send(op, model.send(attr))
              else
                attr_value = model.send(attr)
                unless attr_value.respond_to?(op)
                  fail "#{model.class} attribute '#{attr}' must respond to #{op}"
                end
                attr_value.send(op, operand)
              end
            }
          else
            procs << ->(model) {
              unless model.respond_to?(attr)
                fail "'#{attr}' is not an attribute or method of #{model.class}"
              end
              model.send(attr) == rhs
            }
          end
        end
      end
      procs
    end

    def compile_op(op)
      case op.to_sym
        when :==, :eq, :'$eq'
          :==
        when :!=, :ne, :'$ne'
          :!=
        when :>, :gt, :'$gt'
          :>
        when :>=, :ge, :gte, :'$gte'
          :>=
        when :<, :lt, :'$lt'
          :<
        when :<=, :le, :lte, :'$lte'
          :<=
        when :include, :include?, :in, :'$in'
          :include?
        when :exclude, :exclude?, :nin, :'$nin'
          :exclude?
        else
          nil
      end
    end

    def init_methods
      scope.each_key do |model_class|
        define_singleton_method(model_class.collection_name.to_sym) do
          self.models[model_class]
        end
      end
    end


  end
end end end
