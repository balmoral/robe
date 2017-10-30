require 'robe/common/trace'

module Robe; module DB;
  class Model
    class Embedding < Robe::Model

      attr :type, :model_class, :local_attr

      def initialize(model_class, **args)
        raise ArgumentError, 'model_class should be a class' unless Class === model_class

        name_space = model_class.name.split('::')[0..-2].join('::')

        super **args.merge(
          model_class: model_class,
          foreign_class_name: "#{name_space}::#{args[:collection].to_s.singularize.camel_case}"
        )

        model_class.attr local_attr

        embedding = self
        model_class.class_eval do
          define_method(embedding.local_attr) do
            assoc.resolve(embedding)
          end
        end
      end

      def many?
        type == :embed_many
      end

      def one?
        type == :embed_one
      end

      def <=>(other)
        local_attr <=> other.local_attr
      end

      def ==(other)
        local_attr == other.local_attr
      end

    end
  end
end end