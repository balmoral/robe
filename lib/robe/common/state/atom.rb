class Object
  def deep_dup
    dup
  end
end

class Array
  def deep_dup
    map {|e| e.deep_dup}
  end
end

class Set
  def deep_dup
    map {|e| e.deep_dup}
  end
end

class Hash
  def deep_dup
    {}.tap do |d|
      each do |key, value|
        d[key] = value.deep_dup
      end
    end
  end
end

module Robe; module State
  class Atom 

    class State

      def self.attrs
        @attrs ||= []
      end

      def self.attr(*args)
        # puts "#{__FILE__}[#{__LINE__}] #{self.class.name}##{__method__}(#{args})"
        args.each do |attr|
          attr = attr.to_sym
          unless attrs.include?(attr)
            index = attrs.size
            attrs << attr
            # readers
            define_method(attr) do
              @values[index]
            end
            writer = :"#{attr}="
            define_method(writer) do |value|
              unless @mutable
                raise RuntimeError, "###{writer} only permitted in mutate! block"
              end
              @values[index] = value
            end
          end
        end

        def self.from_hash(hash, mutable = false)
          new(hash, mutable)
        end

        def self.from_array(array, mutable = false)
          new(array, mutable)
        end

        def self.from_json(string, mutable = false)
          hash = JSON.parse(string)
          new(hash, mutable)
        end

        def initialize(seed = nil, mutable = false)
          # trace __FILE__, __LINE__, self, __method__
          @mutable = mutable
          attrs = self.class.attrs
          @values = Array.new(attrs.size)
          if seed.is_a?(Hash)
            seed.each do |key, value|
              key = key.to_sym
              index = attrs.find_index(key)
              unless index
                raise ArgumentError, "#{key} is not an attribute of #{self.class.name}"
              end
              @values[index] = value
            end
          elsif seed.is_a?(Array)
            unless seed.size == attrs.size
              raise ArgumentError, 'seed array size should be same as number of attributes'
            end
            seed.each_with_index do |value, index|
              @values[index] = value
            end
          elsif seed.nil?
            # nothing to do
          else
            raise ArgumentError, "seed for #{self.class.name} must be an array, hash or nil"
          end
        end

        def clone
          c = super
          c.instance_variable_set(:'@values', @values.clone) # deep_clone
          c
        end

        def dup
          c = super
          c.instance_variable_set(:'@values', @values.dup) # deep_dup
          c
        end

        def mutation_count
          @mutation_count ||= 0
        end

        def mutation_count=(value)
          @mutation_count = value
        end

        def mutable?
          @mutable
        end

        def to_mutable_in_situ
          @mutable = true
        end

        def to_mutable
          m = dup # clone
          m.instance_variable_set(:'@mutable', true)
          m
        end

        def to_immutable
          @mutable = false
          self
        end

        def replicate
          self.class.from_array(to_a, @mutable)
        end

        def to_a
          @values.map(&:dup)
        end

        def to_h
          result = {}
          self.class.attrs.each_with_index do |attr, index|
            result[attr] = @values[index].dup
          end
          result
        end

        # TODO: to_h_without_circulars
        def to_json
          hash = {}
          self.class.attrs.each_with_index do |attr, index|
            hash[attr] = @values[index]
          end
          hash.to_json
        end
        
      end
    end

    class << self
      def state_class
        @state_class ||= Class.new(State)
      end

      def attr(*args)
        state_class.attr(*args)

        args.each do |arg|

          # read method is passed on to state
          define_method(arg) do
            @state.send(arg)
          end

          # writer method
          # if state is immutable then is shortcut for mutate!(attr: value)
          # else if state is already mutable will call state writer
          writer = :"#{arg}="
          define_method(writer) do |value|
            if @state.mutable?
              @state.send(writer, value)
            else
              mutate!(arg => value)
            end
          end

        end
      end
    end

    # seed for store should kwargs to allow subclasses to use kwargs
    def initialize(**seed)
      # trace __FILE__, __LINE__, self, __method__, "(#{seed})"
      @state = self.class.state_class.new(seed)
      @observer_id = 0
      @observers = []
    end

    # Temporarily set the state to mutable for the purpose of initializing.
    # WARNING - it is up to the caller to observe this convention.
    #
    # `values`, if given, should be kwargs of attr=>value pairs
    # and state attributes will be set to these values.
    #
    # `block`, if given, may call any methods on the store (self)
    # which has mutable state while inside a initialize! call.
    #
    def initialize!(**values, &block)
      #trace __FILE__, __LINE__, self, __method__, "(#{attrs}, #{block.class})"
      prior_mutable = @state.mutable?
      @state.to_mutable_in_situ
      values.each do |attr, value|
        @state.send(:"#{attr}=", value)
      end
      block.call if block
      @state = @state.to_immutable unless prior_mutable
      self
    end

    def to_h
      @state.to_h
    end

    def mutable?
      @state.mutable?
    end

    def mutation_count
      @state.mutation_count
    end

    def mutation_count=(value)
      @state.mutation_count = value
    end

    # returns a deep clone of the atom
    # which also clones the state, which in turn clones all non-scalar values
    # i.e. tries to be inadvertent-mutation safe as possible
    def clone
      c = super
      c.instance_variable_set(:'@state', @state.clone)
      c
    end

    # returns a deep dup of the atom
    # which also clones the state, which in turn clones all non-scalar values
    # i.e. tries to be inadvertent-mutation safe as possible
    def dup
      d = super
      d.instance_variable_set(:'@state', @state.dup)
      d
    end

    def snapshot
      dup
    end

    # Copy state from other atom of same class
    # and broadcast change of state to all observers
    # with prior state as argument.
    def copy!(other_atom)
      unless other_atom.class == self.class
        raise ArgumentError, 'can only copy atom of same class'
      end
      prior = snapshot
      @state = other_atom.instance_variable_get(:'@state').replicate.to_immutable
      broadcast(prior)
    end

    # Mutate a non-scalar attribute value such as an array, hash, set, etc.
    # A duplicate is made of the attribute value via #dup.
    # If a method name is given the method is called on the duplicate with any given args.
    # If a block is given, the block is called with the duplicate as the argument.
    # Then the atom's attribute is mutated/set to the altered duplicate value.
    # TODO: a completely safe way to ensure non-scalars are not mutated inadvertently
    def mutate_dup!(attr, method = nil, *args, &block)
      dup = send(attr).dup
      dup.send(method, *args) if method
      block.call(dup) if block
      self.send(:"#{attr}=", dup)
    end

    # `#mutate!` is re-entrant: state is mutable within a mutate! block
    # and remains so if mutate! calls are nested.
    #
    # During a mutate! the state is deeply duplicated and becomes mutable.
    #
    # `values`, if given, should be kwargs of attr=>value pairs
    # and state attributes will be set to these values.
    #
    # `block`, if given, may call any methods on the store (self)
    # which has mutable state while inside a mutate! call.
    #
    # At the conclusion of mutation the state is made immutable
    # and all observers notified, with the atom in its prior state
    # provided for diffing, i.e. broadcast to observers is done at
    # conclusion of outer mutate! call.
    #
    # TODO: optimise clone so it doesn't clone any given values
    def mutate!(**values, &block)
      #trace __FILE__, __LINE__, self, __method__, "(#{attrs}, #{block.class})"
      prior_mutable = @state.mutable?
      # trace __FILE__, __LINE__, self, __method__, " : prior_mutable = #{prior_mutable}"
      unless prior_mutable
        prior = snapshot
        @state = @state.to_mutable
      end
      values.each do |attr, value|
        @state.send(:"#{attr}=", value)
      end
      block.call if block
      # trace __FILE__, __LINE__, self, __method__, " : prior_mutable = #{prior_mutable}"
      unless prior_mutable
        @state = @state.to_immutable
        # trace __FILE__, __LINE__, self, __method__, " : @state.class=#{@state.class} prior.class=#{prior.class}"
        broadcast(prior)
      end
      self
    end

    # Register an observer callback for any mutation.
    # Callback proc or block should expect prior state as argument
    # It will called after any mutation.
    # Returns a observer id for later unobserve if required.
    def observe(attr: nil, attrs: nil, eval: nil, who: nil, &block)
      (attrs ||= []) << attr if attr
      who ||= 'unknown observer'
      # trace __FILE__, __LINE__, self, __method__, "(attrs: #{attrs}, eval: #{eval.class}, who: #{who}, block: #{block.class})"
      @observer_id += 1
      # trace __FILE__, __LINE__, self, __method__, " set @observer_id=#{@observer_id}"
      @observers << { id: @observer_id, who: who, attrs: attrs, eval: eval, callback: block, terminated: false }
      # trace __FILE__, __LINE__, self, __method__, " return @observer_id=#{@observer_id}"
      @observer_id
    end

    def unobserve(id)
      i = @observers.index { |e| e[:id] == id }
      @observers.delete_at(i)[:terminated] = true if i
    end

    def observer?(id)
      (observer = @observers.detect { |e| e[:id] == id }) && !observer[:terminated]
    end

    # compatibility with Store
    alias_method :subscribe, :observe
    alias_method :unsubscribe, :unobserve
    alias_method :subscriber?, :observer?

    # to mimic a store
    def state
      self
    end
    
    def state_to_h
      @state.to_h
    end

    def state_to_a
      @state.to_a
    end

    def state_to_json
      @state.to_json
    end

    protected

    # Broadcast change of state to all subscribers.
    # The subscriber callbacks will be given the prior state
    # and store as arguments.
    def broadcast(prior)
      # trace __FILE__, __LINE__, self, __method__, " broadcasting change from #{prior} to #{self}"
      inc_mutation_count
      # important that we dup observers before iterating as subscribers
      # may delete other subscribers (for instance through bindings)
      @observers.dup.each do |observer|
        # an observer can be terminated/unsubscribed by another earlier interested subscriber
        unless observer[:terminated]
          attrs = observer[:attrs]
          eval = observer[:eval]
          if attrs || eval
            changed = if eval
              # trace __FILE__, __LINE__, self, __method__, " : calling eval for observer at #{observer[:who]}"
              eval.call(prior) != eval.call(self)
            else
              false
            end
            if !changed && attrs
              attrs.each do |attr|
                if prior.send(attr) != self.send(attr)
                  changed = true
                  break
                end
              end
            end
          else
            changed = true
          end
          if changed
            observer[:callback].call(prior)
          end
        end
      end
    end

    def inc_mutation_count
      self.mutation_count += 1
    end

  end
end end

