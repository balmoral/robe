
module Robe
  module State

      # A binding associates a change in a store due to an action
      # via a bound callback with a value derived from the store.
      class Binding
        attr_reader :store, :resolve_block, :values

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
        #  Binding.new(store, ->(prior){ prior.name != store.state.name || prior.date != store.state.date } ) do |prior|
        #    # return
        #  end
        #
        # NB - if no result block is given then the value of the resolved binding will be the last given value based on a call to the store.
        def initialize(store, *values, &resolve_block)
          unless store.is_a?(Robe::State::Store) || store.is_a?(Robe::State::Atom)
            raise ArgumentError, "#{self.class.name}##{__method__} bindings require a Robe::State::Store or Robe::State::Atom)"
          end
          @store, @resolve_block = store, resolve_block
          @method_values = @proc_values = nil
          if values.first.is_a?(Hash)
            add_method_values(store, values.first)
          else
            values.each do |value|
              if value.is_a?(Proc) || value.is_a?(Method)
                (@proc_values ||= []) << value
              elsif value.is_a?(Symbol) || value.is_a?(String)
                add_method_value(store, value)
              elsif value.is_a?(Hash)
                add_method_values(store, value)
              else
                raise ArgumentError, "binding value must be a Symbol (for store method name) or a Proc or a Hash"
              end
            end
          end
          unless @resolve_block
            if @method_values.size > 0
              @resolve_block ||= ->(_prior) {
                method_name, args = @method_values.last
                store.send(method_name, *args)
             }
            else
              raise ArgumentError, "#{self.class.name}##{__method__} binding requires a result block if no values provided"
            end
          end
          @subscription_id = nil
        end

        def to_s
          "#{self.class} : store=#{store.class}"
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
            raise RuntimeError, "binding is already activated"
          end
          unless callback
            raise ArgumentError, "#{self.class.name}##{__method__} expects a callback block"
          end
          @subscription_id = store.subscribe do | prior |
            if changed?(prior)
              callback.call(prior)
            end
          end
        end

        def activated?
          !!@subscription_id
        end

        def changed?(prior)
          changed = true
          if @proc_values
            @proc_values.each do |value|
              return true if value.call(prior)
            end
            changed = false
          end
          if @method_values
            @method_values.each do |method_name, args|
              prior = prior ? prior.send(method_name, *args) : nil
              current = if store.is_a?(Robe::State::Atom)
                store.send(method_name, *args)
              else
                store.state ? store.state.send(method_name, *args) : nil
              end
              return true unless prior == current
            end
            changed = false
          end
          changed
        end

        # Returns the result of calling the resolve_block,
        # passing the resolve_block the prior state of
        # of the bound store. If prior state is not
        # given then the resolve_block is called with
        # the current state of the store.
        def resolve(prior = nil)
          @resolve_block.call(prior || store.state)
        end

        def deactivate
          if @subscription_id
            store.unsubscribe(@subscription_id)
            @subscription_id = nil
            @resolve_block = ->{
              Robe.logger.warn "binding #{where} store=#{store.class} @subscription_id=#{@subscription_id} object_id=#{object_id} has been deactivated. Likely cause is nested bindings."
            }
          end
        end

        private

        def add_method_values(store, hash)
          hash.each do |method_name, args|
            add_method_value(store, method_name, args)
          end
        end

        def add_method_value(store, method_name, args = [])
          method_name = method_name.to_sym
          unless store.respond_to?(method_name)
            raise ArgumentError, "#{store.class} does not respond to #{method_name}"
          end
          (@method_values ||= []) << [method_name, args]
        end

      end
  end
end

