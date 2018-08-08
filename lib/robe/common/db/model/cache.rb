require 'robe/common/promise'

module Robe
  module DB
    class Model
      class Cache

        attr_reader :scope

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
        # TODO: all filters/scope to specify which associations are automatically loaded
        # into cache, e.g. { Product => { action_code: BAKE, recipe: :all, ... }}
        # TODO: how to handle product->recipe->ingredients

        def initialize(*classes_and_filters)
          # trace __FILE__, __LINE__, self, __method__, " : classes_and_filters=#{classes_and_filters}"
          init_vars
          init_scope(*classes_and_filters)
          init_methods
        end

        # Returns promise with self as value when all scoped classes loaded.
        def load
          init_vars{}
          promises = {}
          # trace __FILE__, __LINE__, self, __method__
          # Nil all classes current cache to force them back to database.
          scope.each do |model_class, _filter|
            # @prior_caches[model_class] = model_class.cache
            model_class.cache = nil
            @models[model_class] = {}
            @indexes[model_class] = {}
            promises[model_class] = Robe::Promise.new
          end
          # get promises for each model
          scope.each do |model_class, filter|
            filter = {} if filter.nil? || filter == :all
            # trace __FILE__, __LINE__, self, __method__, " : #{model_class} : filter = #{filter} Robe.client?=#{Robe.client?} Robe.server?=#{Robe.server?}"
            promises[model_class] = model_class.find(**filter.symbolize_keys)
          end
          # wait for all to resolve before setting model caches, etc
          promises.values.to_promise_when.then do
            promises.each do |model_class, promise|
              result = promise.value.to_a
              # trace __FILE__, __LINE__, self, __method__, " : #{model_class} : result.size = #{result.size}"
              class_models = @models[model_class] = {}
              result.each do |model|
                class_models[model.id] = model
              end
              model_class.cache = self # from now on we want the class to go through self
            end
            self
          end.fail do |error|
            trace __FILE__, __LINE__, self, __method__, " : ERROR : #{error}"
            error
          end
        end

        def reload
          # prior_caches = @prior_caches
          init_vars # nils @prior_caches
          load.to_promise.then do |result|
            # @prior_caches = prior_caches
            result
          end
        end

        def stop
          model_classes.each do |model_class|
            if model_class.cache == self
              model_class.cache = nil # @prior_caches[model_class]
            end
          end
          init_vars
        end

        def model_classes
          @models.keys
        end

        # If model_class is nil return a hash[model_class] of hashes[id].
        # If model_class is given return a hash of models keyed by id.
        def models(model_class = nil)
          model_class ? @models[model_class] : @models
        end

        # Returns an array of models of model_class.
        # filter is hash keyed by attribute and value to match
        # e.g. **{ product_id: product.id, week: week, action: action }
        # NB - should be faster than general #find  - it uses hash indexes
        def find_eq(model_class, **filter)
          # return find(model_class, **filter)
          attrs = filter.keys
          index = self.index(model_class, attrs)
          key = attrs.size == 1 ? filter.values.first : filter.values
          index[key] || []
        end

        def find(model_class, **filter)
          class_models = models(model_class) || []
          if class_models.empty? || filter.empty?
            class_models.values
          else
            # optimize for simple id query
            if filter.size == 1 && (id = filter.delete(:id) || filter.delete(:_id)) && id.is_a?(String)
              model = class_models[id]
              model ? [model] : []
            else
              procs = compile_filter(filter)
              class_models.values.select { |model|
                procs.reduce(true) { |memo, proc|
                  memo && proc.call(model)
                }
              }
            end
          end
        end

        def find_id(model_class, id)
          @models[model_class][id]
        end

        def includes?(model_class, id)
          !!find_id(model_class, id)
        end

        # expected to be called by a Robe::DB::Model instance
        def insert(model)
          models = @models[model.class]
          if models[model.id]
            fail "#{self.class.name}##{__method__} : model #{model.class} id #{model.id} already in cache"
          end
          models[model.id] = model
          reset_class_indexes(model.class)
          self
        end

        # expected to be called by a Robe::DB::Model instance
        def delete(model)
          @models[model.class].delete(model.id)
          reset_class_indexes(model.class)
          self
        end

        # expected to be called by a Robe::DB::Model instance
        def update(model)
          reset_class_indexes(model.class)
          self
        end

        def clear(model_class)
          @models[model_class] = {}
          reset_class_indexes(model.class)
        end

        private

        def index(model_class, attrs)
          attr = attrs.size == 1 ? attrs.first : nil
          class_indexes = (@indexes[model_class] ||= {})
          class_index = class_indexes[attrs]
          unless class_index
            class_index = class_indexes[attrs] = {}
            @models[model_class].values.each do |model|
              key = attr ? model.send(attr) : attrs.map { |attr| model.send(attr) }
              (class_index[key] ||= []) << model
            end
          end
          class_index
        end

        def reset_class_indexes(model_class)
          @indexes[model_class] = {}
        end

        def init_vars
          @models = {}
          @indexes = {}
          # @prior_caches = {}
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
            lhs = lhs.to_s
            if lhs == '$and' || lhs  == 'and'
              # inner_procs must be compiled outside eval proc
              inner_procs = rhs.map { |e| compile_filter(e) }
              procs << ->(model) { eval_rhs_and(inner_procs, model) }
            elsif lhs == '$or' || lhs == 'or'
              # inner_procs must be compiled outside eval proc
              inner_procs = rhs.map { |e| compile_filter(e) }
              procs << ->(model) { eval_rhs_or(inner_procs, model) }
            else
              # is filter of form { code: 'XYZ' } or { code: { eq: 'XYZ'} }
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
                # assume we've got a simple attr => value pair implying equality comparision
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

        def eval_rhs_and(rhs_procs, model)
          rhs_procs.each do |inner_procs|
            inner_procs.each do |proc|
              return false unless proc.call(model)
            end
          end
          true
        end

        def eval_rhs_or(rhs_procs, model)
          # AND between each rhs_proc,
          # OR between each inner_proc
          rhs_procs.each do |inner_procs|
            return false unless eval_inner_or(inner_procs, model)
          end
          true
        end

        def eval_inner_or(inner_procs, model)
          inner_procs.each do |proc|
            return true if proc.call(model)
          end
          false
        end

        def compile_op(op)
          case op.to_s
            when :'$eq', 'eq', '=='
              :==
            when :'$ne', 'ne', '!='
              :!=
            when :'$gt', 'gt', '>',
              :>
            when '$gte', 'ge', 'gte', '>='
              :>=
            when '$lt', 'lt', '<'
              :<
            when '$lte', 'le', 'lte', '<='
              :<=
            when '$in', 'in'
              :include?
            when '$nin', 'nin'
              :exclude?
            when 'include', 'include?'
              :include?
            when 'exclude', 'exclude?'
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
    end
  end
end
