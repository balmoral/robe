
require 'robe/common/util'
require 'robe/common/state/binding'

module Robe
  module Client
    module Browser
      module DOM
        class TagArray
          include Enumerable

          def initialize(first)
            @contents = []
            self.send(:+, first)
          end

          def each(&block)
            @contents.each(&block)
          end

          def +(el_or_array)
            el_or_array
            if el_or_array.is_a?(Enumerable)
              @contents.concat(el_or_array)
            else
              @contents << el_or_array
            end
            self
          end

          def *(n)
            @contents = @contents * n
          end
        end

        class Tag
          attr_accessor :tag_name, :params

          def initialize(tag_name = :div, *args)
            self.tag_name = tag_name
            self.params = args.first.is_a?(Hash) ? args.first : { content: args }
          end

          # define methods for common element attributes & properties
          %i[
            aria autocomplete autofocus
            checked content css
            data disabled enabled for
            height href id
            name on props properties
            required
            scope src selected style
            type value width
          ].each do |attr|
            if attr == :content
              define_method(attr) do | *args |
                params[attr] = args
                self
              end
            elsif %i(css).include?(attr)
              define_method(attr) do | *args |
                params[:class] = args
                self
              end
            else
              define_method(attr) do | *args |
                params[attr] = args.first
                self
              end
            end
          end

          def +(tag_or_array)
            tag_or_array = self.class.new(:span, arg) if tag_or_array.is_a?(String)
            TagArray.new(self) + tag_or_array
          end

          def *(n)
            TagArray.new(self) * n
          end

          # Create a binding to the given store.
          # When the state of store is mutated the given block will be called
          # and expected to provide a dom element.
          def bind(store, state_method = nil, *state_method_args, where: nil, &block)
            binding = Robe::State::Binding.new(store, state_method, *state_method_args, where: where, &block)
            self << binding
          end

          alias_method :[], :content

          def <<(arg)
            # arg = self.class.new(:span, arg) if arg.is_a?(String)
            (params[:content] ||= []) << arg
            self
          end

          # Returns a Browser::DOM::Element
          def to_element
            Robe.dom.tag(tag_name, params)
          end

          def append_to_body
            Robe.document.body << self.to_element.to_n
          end

        end
      end
    end
  end
end

