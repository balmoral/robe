# http://redux.js.org/docs/recipes/ImplementingUndoHistory.html

require 'robe/common/redux/atom'

module Robe; module Redux
  class History < Robe::Redux::Atom

      attr :max_size, :version, :past, :present, :future

      def self.initial(present: nil, max_size: nil)
        new(
          max_size: max_size,
          version: 0,
          past: [],
          present: present,
          future: []
        )
      end

      def initialize(version: 0, past: [], present: nil, future: [], max_size: nil)
        super
      end

      def past?
        past.size > 0
      end

      def future?
        future.size > 0
      end

      def present?
        !!present
      end

      alias_method :can_undo?, :past?
      alias_method :can_redo?, :future?

      def undo
        if can_undo?
          mutate! do
            self.version = version - 1
            self.future = [present] + future
            self.present = past.last
            self.past = past[0..-2]
          end
        end
      end

      alias_method :back, :undo

      def redo
        if can_redo?
          mutate! do
            self.version = version + 1
            self.past = past + [present]
            self.present = future.first
            self.future = future[1..-1]
          end
        end
      end

      alias_method :forward, :redo

      def versions
        past.size + future.size
      end

      def go_to_version(v)
        while can_redo? && version < v
          self.redo # don't use plain redo - it is a loop control
        end
        while can_undo? && version > v
          self.undo
        end
      end

      def clear
        mutate! do
          self.version = 0
          self.present = nil
          self.past = []
          self.future = []
        end
      end

      # set the present state to given state,
      # add the previous present state to the past,
      # and empty the future
      def present!(state)
        past = self.past
        past = past[1..-1] if past.size == max_size
        self.version = version + 1
        self.max_size = max_size
        self.past = past + [present]
        self.present = state
        self.future = []
      end

      alias_method :now, :present
      alias_method :now!, :present!
      alias_method :now?, :present?

  end
end end

