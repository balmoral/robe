module Robe; module Redux

  # A binding associates a change in a store due to an action
  # via a bound callback with a value derived from the store.
  class Binding
    attr_reader :store, :bound_block, :where

    # bound block 'provides' bound value
    def initialize(store, store_method = nil, *store_method_args, where: nil, &bound_block)
      # trace __FILE__, __LINE__, self, __method__, " : store_method=#{store_method}"
      @where = where || 'unspecified bind location'
      unless store.is_a?(Robe::Redux::Store) || store.is_a?(Robe::Redux::Atom)
        raise ArgumentError, "#{self.class.name}##{__method__} store must be Redux store (called from #{where})"
      end
      unless bound_block
        raise ArgumentError, "#{self.class.name}##{__method__} expects a bound block (called from #{where})"
      end
      @store, @bound_block = store, bound_block
      @store_method, @store_method_args = store_method, store_method_args
      @subscription_id = nil
    end

    def to_s
      "#{self.class} : store=#{store.class} where=#{where}"
    end

    # callback is an intermediate subscriber block which manages the binding
    def bind(&callback)
      if @subscription_id
        raise RuntimeError, "already subscribed to store=#{store.class} where=#{where}"
      end
      unless callback
        raise ArgumentError, "#{self.class.name}##{__method__} expects a callback block"
      end
      # trace __FILE__, __LINE__, self, __method__, " : BIND : store=#{store.class} : where=#{where}"
      @subscription_id = store.observe(who: where) do | prior |
        # trace __FILE__, __LINE__, self, :bind, " : where=#{where} store=#{store.class} store=#{store.state} prior_store=#{prior_store} changed?=#{changed?(prior_store)}  | calling #{bound_block.class}"
        if changed?(prior)
          # trace __FILE__, __LINE__, self, __method__, " : where=#{where} store=#{store.class} store=#{store.state} prior_store=#{prior} changed?=true | calling #{bound_block.class}"
          callback.call(prior)
        end
      end
    end

    def bound?
      !!@subscription_id
    end

    def changed?(prior)
      if @store_method
        # trace __FILE__, __LINE__, self, __method__, " : where=#{where} store=#{store.class} store=#{store.state} prior_store=#{prior_store} @store_method=#{@store_method} prior=#{prior} current=#{current}"
        if @store_method.is_a?(Proc)
          @store_method.call(prior)
        else
          prior = prior ? prior.send(@store_method, *@store_method_args) : nil
          current = if store.is_a?(Robe::Redux::Atom)
            store.send(@store_method, *@store_method_args)
          else
            store.state ? store.state.send(@store_method, *@store_method_args) : nil
          end
        end
        # trace __FILE__, __LINE__, self, __method__, " : where=#{where} store=#{store.class} store=#{store.state} prior_store=#{prior_store} @store_method=#{@store_method} prior=#{prior} current=#{current}"
        prior != current
      else
        true
      end
    end

    # when a binding is unbound ()i.e. it was in a branch of a tree which has been replaced)
    # its bound_block will be nil. However...
    def resolve(prior)
      bound? && @bound_block.call(prior)
    end

    def initial
      @bound_block.call(store)
    end

    def unbind
      if @subscription_id
        # trace __FILE__, __LINE__, self, __method__, " : UNBIND : store=#{store.class} : where=#{where}"
        store.unsubscribe(@subscription_id)
        @subscription_id = nil
        @bound_block = ->{
          Robe.logger.warn "binding #{where} store=#{store.class} @subscription_id=#{@subscription_id} object_id=#{object_id} has been unbound. Likely cause is nested bindings."
        }
      end
    end

  end
end end

