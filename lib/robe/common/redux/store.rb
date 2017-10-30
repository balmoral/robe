
# http://redux.js.org/docs/basics/Store.html

module Robe; module Redux
  class Store

    class << self

      def reducers
        @reducers ||= superclass < Robe::Redux::Store ? superclass.reducers.dup : {}
      end

      # Register a block to handle (reduce) a dispatched action.
      # Define instance method which is shortcut to dispatch for the action.
      def reduce(action, &block)
        # trace __FILE__, __LINE__, self, __method__, " : action=#{action} : block=#{block.class}"
        reducers[action] = block
        define_method action do |*args|
           dispatch(action, *args)
        end
      end

      # Defines a method in the store which calls the same method on the state.
      # Expects that the state method will not change/mutate the state.
      def read_state(*methods)
        methods.each do |method|
          define_method method do |*args, &block|
            state.send(method, *args, &block)
          end
        end
      end

      # Defines a reducer whose action is the method name.
      # Defines a method in the store which call dispatch for the method/action.
      # The reducer will create a duplicate of the state before calling the
      # method on the new state. Expects that the method called on the new
      # state may change it. Allows for safe handling of mutable state objects.
      def reduce_dup(*methods)
        methods.each do |method|
          reduce method do |*args, &block |
            # trace __FILE__, __LINE__, self, __method__, " : method=#{method} : state.class=#{state.class} state=#{state} : args=#{args} : block=#{block.class}"
            new_state = state.dup
            # trace __FILE__, __LINE__, self, __method__, " : method=#{method} : new_state.class=#{new_state.class} new_state=#{new_state}"
            new_state.send(method, *args, &block)
            # trace __FILE__, __LINE__, self, __method__, " : method=#{method} : new_state.class=#{new_state.class} new_state=#{new_state}"
            new_state
          end
        end
      end

      # Defines a reducer whose action is the method name.
      # Defines a method in the store which call dispatch for the method/action.
      # The reducer simply calls the method on the state and expects
      # the state to create a new state instance if necessary.
      def reduce_mutate(*methods)
        methods.each do |method|
          reduce method do |*args, &block |
            # trace __FILE__, __LINE__, self, __method__, " : method=#{method} : state.class=#{state.class} state=#{state} : args=#{args} : block=#{block.class}"
            new_state = state.send(method, *args, &block)
            # trace __FILE__, __LINE__, self, __method__, " : method=#{method} : new_state.class=#{new_state.class} new_state=#{new_state}"
            new_state
          end
        end
      end

      def reducer?(action)
        !!reducers[action]
      end

    end

    attr_reader :state, :subscriptions

    # initial_state
    #   - any object which represents state in the store
    #   - states should be immutable, e.g. Robe::Immutable
    #  If a block is given it will be called with self as argument.
    def initialize(initial_state = nil, &block)
      # trace __FILE__, __LINE__, self, __method__, "(#{initial_state})"
      @state = initial_state
      @subscription_id = 0
      @subscriptions = {}
      block.call if block
    end

    # Dispatches the given action with optional arguments:
    # - the current state of the store is held as old_state
    # - the registered reducer for the action is called
    #   inside instance_exe (so it has access to store as self)
    #   with the arguments given to dispatch.
    # - the current state of the store is set to the
    #   return value from the reducer
    # - subscribers for the action are called
    #   with the prior state and store as arguments
    #
    # If the state changes (object identity)
    # then broadcasts change to all subscribers.
    #
    # Returns the mutated (or unaltered) state.
    #
    # TODO: handle promises returned by actions.
    def dispatch(action, *args)
      reducer = self.class.reducers[action]
      if reducer
        prior_state = @state
        @state = instance_exec(*args, &reducer)
        unless prior_state.object_id == @state.object_id
          broadcast(prior_state)
        end
      else
        raise ArgumentError, "no reducer provided for action #{action} in #{self.class.reducers}"
      end
      @state
    end

    # Register a subscriber callback for an action.
    #
    # Callback proc or block should expect prior state as argument
    #
    # It will called after action is reduced.
    #
    # If action not given or action == nil then
    # the callback will be notified of all actions.
    #
    # Returns a subscription id for later unsubscribe if required.

    def subscribe(who: 'unknown subscriber', &block)
      # trace __FILE__, __LINE__, self, __method__, "(who: #{who}, block: #{block.class})"
      @subscription_id += 1
      # trace __FILE__, __LINE__, self, __method__, " set @subscription_id=#{@subscription_id}"
      subscriptions[@subscription_id] = { who: who, callback: block, terminated: false }
      # trace __FILE__, __LINE__, self, __method__, " return @subscription_id=#{@subscription_id}"
      @subscription_id
    end

    def unsubscribe(id)
      # trace __FILE__, __LINE__, self, __method__, "(#{id})"
      subscription = subscriptions[id]
      subscription[:terminated] = true if subscription
    end

    def subscribed?(id)
      !!subscriptions[id]
    end

    protected

    # Broadcast change of state to all subscribers.
    # The subscriber callbacks will be given the prior state
    # and store as arguments.
    def broadcast(prior_state)
      # important that we dup subscriptions before iterating
      # as subscribers they may delete other subscribers
      # (for instance through bindings)
      subscriptions.values.dup.each do |subscription|
        # a subscription can be terminated/unsubscribed by another earlier interested subscriber
        unless subscription[:terminated]
          subscription[:callback].call(prior_state, self)
        end
      end
    end

  end
end end

