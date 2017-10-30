require 'robe/common/model'
require 'robe/common/redux/store'

module Robe; module Redux
  class ModelStore < Robe::Redux::Store
    include Enumerable

    # def self.inherited(child_class)
    #   trace __FILE__, __LINE__, self, __method__, "#{self}.inherited(#{child_class})"
    #   child_class.model(model_class)
    # end

    def self.model(model_class)
      # trace __FILE__, __LINE__, self, __method__, "(#{model_class})"
      @model_class = model_class
      read_state(*(model_class.read_attrs + model_class.read_state_methods))
      reduce_dup(*(model_class.write_attrs + model_class.reduce_dup_methods))
      reduce_mutate(*model_class.reduce_mutate_methods)
    end

    def self.model_class
      @model_class
    end

    def initialize(initial = self.class.model_class.new, &block)
      # trace __FILE__, __LINE__, self, __method__, " : initial.class=#{initial.class}  self.class.model_class=#{self.class.model_class}"
      unless initial.is_a?(self.class.model_class)
        raise ArgumentError, "model must be a #{self.class.model_class}, not a #{initial.class}"
      end
      super(initial, &block)
    end

  end
end end

