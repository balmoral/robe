

require 'robe/common/state/atom/core_extensions'
require 'robe/common/state/atom/state'
require 'robe/common/state/hook'

# Atom implements an all in one store + state
# with supporting methods for mutation and observation.
# TODO: add history support
#
module Robe
  module State
    class Atom

      def self.inherited(subclass)
        # puts "#{__FILE__}[#{__LINE__}] #{self}.inherited(#{subclass})"
        subclass.state_class.attr(*state_class.attrs)
      end

      def self.state_class
        @state_class ||= Class.new(State)
      end

      def self.attrs
        state_class.attrs
      end

      def self.attr(*args)
        state_class.attr(*args)
        define_attr_methods(*args)
      end

      def self.define_attr_methods(*args)
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

      # seed for store should kwargs to allow subclasses to use kwargs
      def initialize(**seed)
        # trace __FILE__, __LINE__, self, __method__, "(#{seed})"
        @state = self.class.state_class.new(seed)
        @subscriber_id = 0
        @subscribers = []
      end

      def attrs
        self.class.attrs
      end

      # Temporarily set the state to mutable for the purpose of initializing.
      # WARNING - it is up to the caller to subscribe this convention.
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

      def get(attr)
        send(attr)
      end

      def set(attr, value)
        send(:"#{attr}=", value)
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
      # and broadcast change of state to all subscribers
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
      # In the outer mutate! the state is duplicated and memoized
      # to be later passed to subscribers as the prior state.
      #
      # `values`, if given, should be kwargs of attr=>value pairs
      # and state attributes will be set to these values.
      #
      # `block`, if given, may call any methods on the store (self)
      # which has mutable state while inside a mutate! call.
      #
      # At the conclusion of mutation the state is made immutable
      # and all subscribers notified, with the atom in its prior state
      # provided for diffing, i.e. broadcast to subscribers is done at
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

      # Register an subscriber block to be called after mutation.
      # where: can be a string like "#{__FILE__}[#{__LINE__}]" for debugging.
      # The block should expect prior state as its argument.
      # Returns a subscriber id for later unsubscribe if required.
      def subscribe(attr: nil, attrs: nil, eval: nil, where: nil, &block)
        (attrs ||= []) << attr if attr
        where ||= 'unknown'
        # trace __FILE__, __LINE__, self, __method__, "(attrs: #{attrs}, eval: #{eval.class}, where: #{where}, block: #{block.class})"
        @subscriber_id += 1
        # trace __FILE__, __LINE__, self, __method__, " set @subscriber_id=#{@subscriber_id}"
        @subscribers << { id: @subscriber_id, where: where, attrs: attrs, eval: eval, callback: block, terminated: false }
        # trace __FILE__, __LINE__, self, __method__, " return @subscriber_id=#{@subscriber_id}"
        @subscriber_id
      end

      def unsubscribe(id)
        i = @subscribers.index { |e| e[:id] == id }
        @subscribers.delete_at(i)[:terminated] = true if i
      end

      def subscriber?(id)
        (subscriber = @subscribers.detect { |e| e[:id] == id }) && !subscriber[:terminated]
      end

      # use cautiously
      def clear_subscribers
        @subscribers = []
      end

      def subscriber_ids
        @subscribers.map { |e| e[:id] }
      end

      alias_method :observe, :subscribe
      alias_method :unobserve, :unsubscribe
      alias_method :observe?, :subscriber?

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
      def broadcast(prior_state)
        # trace __FILE__, __LINE__, self, __method__, " broadcasting change from #{prior} to #{self}"
        inc_mutation_count
        # important that we dup subscribers before iterating as subscribers
        # may delete other subscribers (for instance through hooks)
        @subscribers.dup.each do |subscriber|
          # a subscriber can be terminated/unsubscribed by another earlier interested subscriber
          unless subscriber[:terminated]
            attrs = subscriber[:attrs]
            eval = subscriber[:eval]
            if attrs || eval
              changed = if eval
                # trace __FILE__, __LINE__, self, __method__, " : calling eval for subscriber at #{subscriber[:where]}"
                eval.call(prior) != eval.call(self)
              else
                false
              end
              if !changed && attrs
                changed = changed?(prior_state, attrs)
              end
            else
              changed = true
            end
            if changed
              subscriber[:callback].call(prior_state)
            end
          end
        end
      end

      def inc_mutation_count
        self.mutation_count += 1
      end

      def changed?(prior, attrs)
        attrs.each do |attr|
          if prior.send(attr) != self.send(attr)
            return true
          end
        end
        false
      end

    end
  end
end

