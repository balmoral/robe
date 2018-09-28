
module Robe
  module State

      # A Binder creates a binding
      #
      # Syntactic sugar as alternative to bind(store, :attr_name).
      #
      # store.bind => Binder.new(store)
      # store.bind.attr_name => Binding.new(store, :attr_name)
      #

      class Binder
        attr_reader :store

        def initialize(store)
          @store = store
        end

        def method_missing(name, *args, &block)
          Binding.new(store, { name => args }, &block)
        end

      end
  end
end

