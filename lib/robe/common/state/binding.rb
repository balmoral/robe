
module Robe
  module State

      # A binding associates a change in a store due to an action
      # via a bound callback with a value derived from the store.
      class Binding
        attr_reader :store, :value_block, :where

        # Create a Binding to a Robe::State::Store or Robe::State::Atom.
        #
        # The given block will be called when the state of the store or
        # atom changes, with the prior state of the store or atom as
        # the argument to the bound block.
        #
        # The bound block should provide an appropriate value if the creator of
        # the binding is expecting a value - e.g. when binding DOM components
        # to state.
        #
        # The where: argument is useful for debugging when you need to determine
        # where the binding was created, e.g. pass "#{__FILE__}[#{__LINE__}]"
        #
        # You can bind to any change or a specific change in the store's state:
        #
        # 1. To bind to any change in the store's state then use:
        #
        #  Binding.new(store) { |prior| ... }
        #
        # 2. To bind to a change in a value returned by a method of the store then use:
        #
        #   Binding.new(store, :method_name) { |prior| ... }
        #
        # The method may or may not be an attribute, if the store provides computed values.
        #
        # For example, if store contains invoices, and computes a total, you may use:
        #
        #  Binding.new(store, :invoice_total) { |prior| ... }
        #
        # 3. To bind to a change in a value returned by a method of the store where the method
        # accepts arguments, then use:
        #
        #   Binding.new(store, :method_name, *method_args) { |prior| ... }
        #
        # For example, if store contains invoices, and computes total for days, you may use:
        #
        #  Binding.new(store, :invoice_total, date)
        #
        # 4. To bind to arbitrary change(s) in the state of the store you may provide a Proc
        # as the second argument. The proc should expect the prior state as its argument,
        # and should# return truthy (true or !nil) if it considers a change has occurred
        # in the state else falsy (false or nil).
        #
        # For example:
        #
        #  Binding.new(store, ->{ |prior| prior.name != store.state.name || prior.date != store.state.date } ) do |prior|
        #    # return
        #  end
        #
        # TODO: consider way to make initialization more elegant!
        #
        def initialize(store, store_method = nil, *store_method_args, where: nil, &value_block)
          @where = where || 'unspecified binding location'
          unless store.is_a?(Robe::State::Store) || store.is_a?(Robe::State::Atom)
            raise ArgumentError, "#{self.class.name}##{__method__} store must be State store (called from #{where})"
          end
          unless value_block
            raise ArgumentError, "#{self.class.name}##{__method__} expects a bound block (called from #{where})"
          end
          @store, @value_block = store, value_block
          @change_proc = @store_method = @store_method_args = nil
          if store_method.is_a?(Proc) || store_method.is_a?(Method)
            @change_proc = store_method
          else
            @store_method, @store_method_args = store_method, store_method_args
          end
          @subscription_id = nil
        end

        def to_s
          "#{self.class} : store=#{store.class} where=#{where}"
        end

        # Activate the binding with a callback block.
        # The binding will subscribe to the store.
        # When the store's state is mutated the binding will
        # determine whether there has been a change between
        # the the prior state and current state (using ==).
        # If a changed has occurred the callback will be
        # called with the prior state as the argument.
        def activate(&callback)
          if activated?
            raise RuntimeError, "binding is already activated from #{where}"
          end
          unless callback
            raise ArgumentError, "#{self.class.name}##{__method__} expects a callback block"
          end
          @subscription_id = store.subscribe(where: where) do | prior |
            if changed?(prior)
              callback.call(prior)
            end
          end
        end

        def activated?
          !!@subscription_id
        end

        def changed?(prior)
            # trace __FILE__, __LINE__, self, __method__, " : where=#{where} store=#{store.class} store=#{store.state} prior_store=#{prior_store} @store_method=#{@store_method} prior=#{prior} current=#{current}"
          if @store_method
            prior = prior ? prior.send(@store_method, *@store_method_args) : nil
            current = if store.is_a?(Robe::State::Atom)
              store.send(@store_method, *@store_method_args)
            else
              store.state ? store.state.send(@store_method, *@store_method_args) : nil
            end
            prior != current
          elsif @change_proc
            @change_proc.call(prior)
          else
            true
          end
        end

        # Returns the result of calling the value_block,
        # passing the value_block the prior state of
        # of the bound store. If prior state is not
        # given then the value_block is called with
        # the current state of the store.
        def value(prior = nil)
          @value_block.call(prior || store.state)
        end

        def deactivate
          if @subscription_id
            store.unsubscribe(@subscription_id)
            @subscription_id = nil
            @value_block = ->{
              Robe.logger.warn "binding #{where} store=#{store.class} @subscription_id=#{@subscription_id} object_id=#{object_id} has been deactivated. Likely cause is nested bindings."
            }
          end
        end

      end
  end
end

