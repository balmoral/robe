
module Robe; module State

  # A hook associates a change in a store due to an action
  # via a hooked callback with a value derived from the store.
  class Hook
    attr_reader :store, :value_block, :where

    # Create a Hook to a Robe::State::Store or Robe::State::Atom.
    #
    # The given block will be called when the state of the store or
    # atom changes, with the prior state of the store or atom as
    # the argument to the hooked block.
    #
    # The hooked block should provide an appropriate value if the creator of
    # the hook is expecting a value - e.g. when hooking DOM components
    # to state.
    #
    # The where: argument is useful for debugging when you need to determine
    # where the hook was created, e.g. pass "#{__FILE__}[#{__LINE__}]"
    #
    # You can hook to any change or a specific change in the store's state:
    #
    # 1. To hook to any change in the store's state then use:
    #
    #  Hook.new(store) { |prior| ... }
    #
    # 2. To hook to a change in a value returned by a method of the store then use:
    #
    #   Hook.new(store, :method_name) { |prior| ... }
    #
    # The method may or may not be an attribute, if the store provides computed values.
    #
    # For example, if store contains invoices, and computes a total, you may use:
    #
    #  Hook.new(store, :invoice_total) { |prior| ... }
    #
    # 3. To hook to a change in a value returned by a method of the store where the method
    # accepts arguments, then use:
    #
    #   Hook.new(store, :method_name, *method_args) { |prior| ... }
    #
    # For example, if store contains invoices, and computes total for days, you may use:
    #
    #  Hook.new(store, :invoice_total, date)
    #
    # 4. To hook to arbitrary change(s) in the state of the store you may provide a Proc
    # as the second argument. The proc should expect the prior state as its argument,
    # and should# return truthy (true or !nil) if it considers a change has occurred
    # in the state else falsy (false or nil).
    #
    # For example:
    #
    #  Hook.new(store, ->{ |prior| prior.name != store.state.name || prior.date != store.state.date } ) do |prior|
    #    # return
    #  end
    #
    # TODO: consider way to make initialization more elegant!
    #
    def initialize(store, store_method = nil, *store_method_args, where: nil, &value_block)
      # trace __FILE__, __LINE__, self, __method__, " : store_method=#{store_method}"
      @where = where || 'unspecified hook location'
      unless store.is_a?(Robe::State::Store) || store.is_a?(Robe::State::Atom)
        raise ArgumentError, "#{self.class.name}##{__method__} store must be State store (called from #{where})"
      end
      unless value_block
        raise ArgumentError, "#{self.class.name}##{__method__} expects a hooked block (called from #{where})"
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

    # Activate the hook with a callback block.
    # The hook will subscribe to the store.
    # When the store's state is mutated the hook will
    # determine whether there has been a change between
    # the the prior state and current state (using ==).
    # If a changed has occurred the callback will be
    # called with the prior state as the argument.
    def activate(&callback)
      if activated?
        raise RuntimeError, "hook is already activated from #{where}"
      end
      unless callback
        raise ArgumentError, "#{self.class.name}##{__method__} expects a callback block"
      end
      # trace __FILE__, __LINE__, self, __method__, " : HOOK : store=#{store.class} : where=#{where}"
      @subscription_id = store.subscribe(where: where) do | prior |
        # trace __FILE__, __LINE__, self, :hook, " : where=#{where} store=#{store.class} changed?=#{changed?(prior)}"
        if changed?(prior)
          # trace __FILE__, __LINE__, self, __method__, " : where=#{where} store.class=#{store.class} changed?=true | calling #{block.class}"
          callback.call(prior)
          # trace __FILE__, __LINE__, self, __method__, " : where=#{where} store.class=#{store.class} called #{block.class}"
        end
        # trace __FILE__, __LINE__, self, :hook, " : where=#{where} store=#{store.class} changed?=#{changed?(prior)}"
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
    # of the hooked store. If prior state is not
    # given then the value_block is called with
    # the current state of the store.
    def value(prior = nil)
      @value_block.call(prior || store.state)
    end

    def deactivate
      if @subscription_id
        # trace __FILE__, __LINE__, self, __method__, " : UNHOOK : store=#{store.class} : where=#{where}"
        store.unsubscribe(@subscription_id)
        @subscription_id = nil
        @value_block = ->{
          Robe.logger.warn "hook #{where} store=#{store.class} @subscription_id=#{@subscription_id} object_id=#{object_id} has been deactivated. Likely cause is nested hooks."
        }
      end
    end

  end
end end

