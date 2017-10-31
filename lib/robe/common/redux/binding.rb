module Robe; module Redux

  # A binding associates a change in a store due to an action
  # via a bound callback with a value derived from the store.
  class Binding
    attr_reader :store, :bound_block, :where

    # block 'provides' bound value
    def initialize(store, state_method = nil, *state_method_args, where: nil, &bound_block)
      # trace __FILE__, __LINE__, self, __method__, " : state_method=#{state_method}"
      @where = where || 'unspecified bind location'
      unless store.is_a?(Robe::Redux::Store) || store.is_a?(Robe::Redux::Atom)
        raise ArgumentError, "#{self.class.name}##{__method__} store must be Redux store (called from #{where})"
      end
      unless bound_block
        raise ArgumentError, "#{self.class.name}##{__method__} expects a bound block (called from #{where})"
      end
      @store, @bound_block = store, bound_block
      @state_method, @state_method_args = state_method, state_method_args
      @subscription_id = nil
    end

    # callback is an intermediate subscriber block which manages the binding
    def bind(&callback)
      raise ArgumentError, "#{self.class.name}##{__method__} expects a callback block" unless callback
      # trace __FILE__, __LINE__, self, __method__, " : store=#{store.class} : callback=#{callback.class} where=#{where}"
      @subscription_id = store.subscribe(who: where) do | prior |
        # trace __FILE__, __LINE__, self, :bind, " : where=#{where} store=#{store.class} state=#{store.state} prior_state=#{prior_state} changed?=#{changed?(prior_state)}  | calling #{bound_block.class}"
        if changed?(prior)
          # trace __FILE__, __LINE__, self, __method__, " : where=#{where} store=#{store.class} state=#{store.state} prior_state=#{prior_state} changed?=true | calling #{bound_block.class}"
          callback.call(prior)
        end
      end
    end

    def changed?(prior)
      if @state_method
        # trace __FILE__, __LINE__, self, __method__, " : where=#{where} store=#{store.class} state=#{store.state} prior_state=#{prior_state} @state_method=#{@state_method} prior=#{prior} current=#{current}"
        if @state_method.is_a?(Proc)
          @state_method.call(prior)
        else
          prior = prior ? prior.send(@state_method, *@state_method_args) : nil
          current = if store.is_a?(Robe::Redux::Atom)
            store.send(@state_method, *@state_method_args)
          else
            store.state ? store.state.send(@state_method, *@state_method_args) : nil
          end
        end
        # trace __FILE__, __LINE__, self, __method__, " : where=#{where} store=#{store.class} state=#{store.state} prior_state=#{prior_state} @state_method=#{@state_method} prior=#{prior} current=#{current}"
        prior != current
      else
        true
      end
    end

    def resolve(prior)
      bound_block.call(prior)
    end

    def initial
      resolve(store)
    end

    def unbind
      store.unsubscribe(@subscription_id) if @subscription_id
      @bound_block = ->{
        Robe.logger.warn "binding #{where} store=#{store.class} @subscription_id=#{@subscription_id} object_id=#{object_id} has been unbound. Likely cause is nested bindings."
      }
    end

  end
end end

