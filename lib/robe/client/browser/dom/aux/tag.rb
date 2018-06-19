
require 'robe/common/util'
require 'robe/common/state/binding'

module Robe; module Client; module Browser; module DOM

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

    # :name,
    %i(id css style name enabled disabled selected checked value type autofocus required for data aria on props href src properties height width content).each do |attr|
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

    # content from binding - shortcut
    def bind(store, state_method = nil, *state_method_args, where: nil, &bound_block)
      binding = Robe::State::Binding.new(store, state_method, *state_method_args, where: where, &bound_block)
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

end end end end

