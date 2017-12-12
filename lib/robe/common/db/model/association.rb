require 'robe/common/trace'

module Robe; module DB;
  class Model
    class Association < Robe::Model

      def self.db
        Robe::DB::Model.db
      end

      attr :type, :model_class, :collection, :owner, :local_key, :local_attr, :foreign_key, :foreign_class_name

      def initialize(model_class, **args)
        raise ArgumentError, 'model_class should be a class' unless Class === model_class

        name_space = model_class.name.split('::')[0..-2].join('::')

        super(
          **args.merge(
            model_class: model_class,
            foreign_class_name: "#{name_space}::#{args[:collection].to_s.singularize.camel_case}"
          )
        )

        # trace __FILE__, __LINE__, self, __method__, " : assoc: model_class=#{model_class} type=#{type} collection=#{collection} local_key=#{local_key} local_attr=#{local_attr}"

        # define model attribute for local_key
        model_class.attr local_key

        # memo for class eval
        assoc = self

        # Define method for getting association (using an instance variable).
        # (use class_eval to get around define_method being private)
        model_class.class_eval do

          # define reader method for local_attr
          define_method(assoc.local_attr) do
            assoc.resolve(self)
          end

          if assoc.has_many?

            # override model write local_key attribute method
            define_method(:"#{assoc.local_key}=") do |value|
              fail "#{self.class.name}##{__method__} : cannot assign local for to has_many association"
            end

            # define writer method for local_attr
            define_method(:"#{assoc.local_attr}=") do |value|
              unless value.is_a?(Enumerable)
                fail "#{self.class.name}##{__method__} : has_many association expects array or enumerable"
              end
              value.each do |e|
                unless e.is_a?(assoc.foreign_class)
                  fail "#{self.class.name}##{__method__} : association expects array of #{assoc.foreign_class} "
                end
              end
              instance_variable_set(:"@#{assoc.local_attr}", value.to_a)
            end

          else # has_one, belongs_to, join

            # override model write local_key attribute method
            # reset local_attr to nil
            define_method(:"#{assoc.local_key}=") do |value|
              set(assoc.local_key, value, self)
              send(:"#{assoc.local_attr}=", nil)
            end

            # define writer method for local_attr
            # set local key to id of given value
            define_method(:"#{assoc.local_attr}=") do |value|
              unless value.nil? || value.is_a?(assoc.foreign_class)
                fail "#{self.class.name}##{__method__} : #{assoc.type} association expects #{assoc.foreign_class}"
              end
              set(assoc.local_key, value && value.id, self)
              instance_variable_set(:"@#{assoc.local_attr}", value)
            end

          end

        end
      end

      def owner?
        owner
      end

      def one?
        !many?
      end

      # maybe in future more many associations
      def many?
        has_many?
      end

      def has_one?
        type == :has_one
      end

      def has_many?
        type == :has_many
      end

      def has?
        has_one? || has_many?
      end

      def owned?
        belongs_to?
      end

      def belongs_to?
        type == :belongs_to
      end

      def join?
        type == :join
      end

      def <=>(other)
        local_attr <=> other.local_attr
      end

      def ==(other)
        local_attr == other.local_attr
      end

      def foreign_class
        @foreign_class ||= Object.const_get(foreign_class_name)
      end

      def on_initialize(model)
        unless has_many?
          associate = model.instance_variable_get("@#{local_attr}") # back door - don't want to trigger resolution
          foreign_key_value = associate ? associate.send(foreign_key) : nil
          local_key_value = model.send(local_key)
          if local_key_value && foreign_key_value
            unless foreign_key_value == local_key_value
              fail "#{model.class} #{type} association : expected foreign_key #{foreign_class_name}##{foreign_key} to match local key #{local_key}"
            end
          elsif associate
            model.set(local_key, foreign_key, self)
          end
        end
      end

      # Resolves this association for the model.
      # If the associated (foreign) model class is not cached the result
      # will be wrapped in a Promise, otherwise it will be the plain result.
      # The appropriate attribute in the model will be set.
      # Typically (sensibly) a cache's scope will include all
      # model classes required to ensure referential completeness
      # (i.e. cache all associated classes).
      # If their is not associate yet and the local_key has not been set
      # then nil will be the result.
      def resolve(model)
        __method = __method__
        # trace __FILE__, __LINE__, self, __method, " : assoc: type=#{type} attr=#{local_attr} collection=#{collection} model.class=#{model.class}"
        associated = model.instance_variable_get("@#{local_attr}") # back door otherwise we chase our tail
        if associated
          if foreign_class.cached?
            associated
          else
            Robe::Promise.value(associated)
          end
        else
          local_key_value = model.send(local_key)
          if local_key_value
            filter = { foreign_key => local_key_value }
            # trace __FILE__, __LINE__, self, __method, " : calling #{foreign_class}.send(#{find_method}, #{filter})"
            associated = foreign_class.send(find_method, **filter)
            if foreign_class.cached?
              model.instance_variable_set(:"@#{local_attr}", associated)
            else
              associated.then do |associated|
                if associated
                  model.instance_variable_set(:"@#{local_attr}", associated)
                  handle_belongs_to(model, associated)
                end
                associated
              end
            end
          else
            foreign_class.cached? ? nil : Robe::Promise.value(nil)
          end
        end
      end

      # Ensure local_keys and foreign_keys are set as required for the
      # model and its associates.
      #
      # If the association is has_one or has_many and the model is owner
      # then save the one or many to db.
      #
      # Returns a promise whose value is the given model.
      def save(model)
        associated = model.instance_variable_get("@#{local_attr}") # back door, don't want to trigger resolution
        promise = nil
        local_key_value = model.send(local_key)
        if has?
          if has_many?
            if associated
              unless associated.is_a?(Enumerable)
                fail "#{model.class} expects has_many attr #{local_attr} to be an array or enumerable"
              end
              associated.each do |a|
                check_associate(model, a, local_key_value, false)
              end
            end
          else # has_one?
            if associated
              check_associate(model, associated, local_key_value, true)
              associated = [associated]
            else
              msg = " : #{model.class} association #{type} : expected #{local_attr} to be set"
              trace __FILE__, __LINE__, self, __method__, msg
              # fail msg
            end
          end
          # is model is the owner, then do the database save of associations here
          if associated && owner?
            associated = associated
            promise = save_associates(local_key_value, associated)
          end
        elsif belongs_to? || join?
          check_associate(model, associated, local_key_value, true)
        else
          fail "unhandled association type #{type}"
        end
        Robe::Promise.value(promise || model)
      end

      def save_associates(local_key_value, associates)
        # delete any associates which are not in given associates
        trace __FILE__, __LINE__, self, __method__, " : associates.class=#{associates.class}"
        current_ids = associates.map(&:id)
        delete_filter = {'$and' => [{foreign_key.to_s => local_key_value}, {'_id' => {'$nin' => current_ids}}]}
        Robe::Promise.value(foreign_class.find(**delete_filter)).then do |expired|
          trace __FILE__, __LINE__, self, __method__, " deleting #{expired.size} expired associations in #{collection}"
          promises = expired.map(&:delete)
          Robe::Promise.when(*promises)
        end.then do
          trace __FILE__, __LINE__, self, __method__, " saving #{associates.size} current associations in #{collection}"
          # save the current associates
          promises = associates.map(&:save)
          Robe::Promise.when(*promises)
        end
      end

      def check_associate(model, associate, local_key_value, local_key_required = false)
        if associate
          check_foreign_class(associate)
          unless local_key_value
            fail "#{type} association : local_key #{model.class}##{local_key} should have been set"
          end
          foreign_key_value = associate.send(foreign_key)
          if foreign_key_value
            unless local_key_value == foreign_key_value
              fail "#{type} association : foreign_key #{associate.class}##{foreign_key} should equal local_key #{model.class}##{local_key}"
            end
          else
            associate.set(foreign_key, local_key_value, self)
          end
        elsif local_key_required && local_key_value.nil?
          fail "#{type} association : local_key #{model.class}##{local_key} should have been set"
        end
      end

      def check_foreign_class(associate)
        unless associate.is_a?(foreign_class)
          fail "#{type} association : #{model.class}##{local_attr} must be a #{foreign_class}, not #{associate.class}"
        end
      end

      # If this association is has_one or has_many, then check the associated
      # model's associations to so whether there is a matching/inverse belongs_to.
      # If so then set the appropriate attribute of the associate to the (owner) model.
      def handle_belongs_to(model, associated)
        __method = __method__
        # trace __FILE__, __LINE__, self, __method__, " : model.class=#{model.class} associated=#{associated.class} has?=#{has?}"
        associated = [associated] unless associated.is_a?(Array)
        # trace __FILE__, __LINE__, self, __method__, " : associated.size=#{associated.size}"
        if has?
          associated.each do |associate|
            # trace __FILE__, __LINE__, self, __method, " : model.class=#{model.class} associate=#{associate.class}"
            inverse = associate.class.belongs_to_association(collection)
            # trace __FILE__, __LINE__, self, __method, " : model.class=#{model.class} associate=#{associate.class}"
            if inverse
              # trace __FILE__, __LINE__, self, __method, " : setting inverse associate.class##{inverse.local_attr} to #{model.class}"
              associate.send(:"#{inverse.local_attr}=", model)
              # trace __FILE__, __LINE__, self, __method
            end
          end
        end
      end

      def find_method
        type == :has_many ? :find : :find_one
      end
    end
  end
end end