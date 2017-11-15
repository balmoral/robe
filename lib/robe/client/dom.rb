require 'robe/common/util'
require 'robe/common/trace'
require 'robe/client/dom/link'
require 'robe/client/dom/tag'

class String
  def as_native
    self
  end
end

module Robe; module Client
  module DOM

    module_function

    HTML_TAGS = ::Robe::Client::Render::HTML::TAGS + ['link']

    HTML_TAGS.each do |tag|
      define_method tag do |*args|
        # puts "#{__FILE__}[#{__LINE__}] : #{self.class.name}##{tag}(#{args})"
        tag_class.new(tag, *args)
      end
    end

    def window
      @window ||= Robe::Client::Browser.window
    end

    def document
      @document ||= Robe::Client::Browser.document
    end

    def clear(element)
      if element
        unbind_descendant_bindings(element)
        element.clear
      end
      nil
    end

    # Returns a Browser::DOM::Element
    def tag(name, *args)
      # trace __FILE__, __LINE__, self, __method__, "(#{name}, #{args})"
      if name == :link || name == 'link'
        args = args.first
        fail 'link expects keyword args' unless Hash === args
        link_class.new(**args).root
      else
        # trace __FILE__, __LINE__, self, __method__, "(#{name}, #{args})"
        # turn args into hash
        args = Hash === args.first ? args.first : { content: args }
        # get content
        content = args.delete(:content) # args[:content]
        content = content.call if content.is_a?(Proc)
        if content.is_a?(Enumerable)
          n = content.size
          if n == 0
            content = nil
          elsif n == 1
            content = content.first
          end
        end
        # trace __FILE__, __LINE__, self, __method__, " : content=#{content})"
        # what's left are other attributes, such as class, style, etc
        attributes = args
        # trace __FILE__, __LINE__, self, __method__, " : name=#{name} attributes=#{attributes})"
        css = attributes[:css] # either :class or :css
        attributes[:class] = css if css
        # trace __FILE__, __LINE__, self, __method__, " : attributes=#{attributes})"
        namespace = attributes[:namespace] ? { namespace: attributes[:namespace] } : {}
        element = document.create_element(name, namespace)
        element.id = attributes[:id] || "#{name}_#{Robe::Util.hex_id(6)}"
        attributes.each do |attribute, value|
          unless attributes == :css || attributes == :content # already dealt with
            ## trace __FILE__, __LINE__, self, __method__, " : attribute=#{attribute} value=#{value}) set"
            set_attribute(element, attribute, value)
            # trace __FILE__, __LINE__, self, __method__, " : attribute=#{attribute} value=#{value}) done"
          end
        end
        # trace __FILE__, __LINE__, self, __method__, " : content=#{content.class} set"
        set_content(element, content)
        # trace __FILE__, __LINE__, self, __method__, " : content=#{content.class} done"
        element
      end
    end

    def bind(store, state_method = nil, *state_method_arg, where: nil, &bound_block)
      binding_class.new(store, state_method, *state_method_arg, where: where, &bound_block)
    end

    # private api follows

    def binding_class
      @@binding_class ||= Robe::Redux::Binding
    end

    def tag_class
      @@tag_class ||= Robe::Client::DOM::Tag
    end

    def link_class
      @@link_class ||= Robe::Client::DOM::Link
    end

    def node_class
      @@node_class || ::Browser::DOM::Node
    end

    def element_class
      @@element_class || ::Browser::DOM::Element
    end

    def component_class
      @@component_class ||= Robe::Client::Component
    end

    def set_attribute(element, attribute, value)
      # trace __FILE__, __LINE__, self, __method__, " value=#{value}" if value.is_a?(Robe::Redux::Binding)
      value = resolve_attribute(element, attribute, value)
      attribute_handler(attribute).call(element, attribute, value)
    end

    def attribute_handler(attribute)
      attribute_handlers[attribute] || default_attribute_handler
    end

    def attribute_handlers
      @attribute_handlers ||= {
        style: ->(element, attribute, value) {
          if value
            style = normalize_style(value)
            element.style(style)
          end
        },
        class: ->(element, attribute, value) {
          if value
            value = if Enumerable === value
              value.map{|e| underscore_to_dash(e)}.join(' ')
            else
              underscore_to_dash(value)
            end
          end
          element[attribute] = value
        },
        on: ->(element, attribute, value) {
          resolve_events(value).each do |event, action|
            element.on(event, &action)
          end
        },
        data: ->(element, attribute, value) {
          resolve_data(value).each do |data_key, data_value|
            element[data_key] = resolve_attribute(element, data_key, data_value)
          end
        :aria
          resolve_aria(value).each do |aria_key, aria_value|
            element[aria_key] = resolve_attribute(element, aria_key, aria_value)
          end
        },
        selected: ->(element, attribute, value) {
          element.selected = value
        },
        checked: ->(element, attribute, value) {
          element.checked = value
        },
        enabled: ->(element, attribute, value) {
          element[:disabled] = !value
        },
        disabled: ->(element, attribute, value) {
          element[:disabled] = value
        },
        props: ->(element, attribute, value) {
          value.each do |p, v|
            element[p] = v
          end
        },
        properties: ->(element, attribute, value) {
          value.each do |p, v|
            element[p] = v
          end
        }
      }
    end

    def default_attribute_handler
      @default_attribute_handler ||= ->(element, attribute, value) {
        if value
          attribute = strip_underscores(attribute)
          unless attribute == :value
            if value.is_a?(String) || value.is_a?(Symbol)
              value = underscore_to_dash(value.to_s)
            end
          end
          # trace __FILE__, __LINE__, self, __method__, " : attribute=#{attribute} value=#{value})"
          if attribute == :iframe
            `console.log(#{"#{__FILE__}##{__LINE__} : #{__method__} : attribute=#{attribute} value=#{value}"})`
          end
        end
        element[attribute] = value
      }
    end

    def resolve_attribute(element, attr, value)
      if value.is_a?(Robe::Redux::Binding)
        # trace __FILE__, __LINE__, self, __method__, " : binding=#{value}"
        resolve_attribute_binding(element, attr, value)
      else
        value
      end
    end

    # the resolved binding will become an attribute of the element
    def resolve_attribute_binding(element, attr, binding)
      # trace __FILE__, __LINE__, self, __method__, " binding=#{binding}"
      element_bindings(element, init: true) << binding
      binding.bind do |prior_state|
        update_element_attribute(binding, prior_state, element, attr)
      end
      binding.initial
    end

    def update_element_attribute(binding, prior_state, element, attr)
      # trace __FILE__, __LINE__, self, __method__, " :action=#{action} store=#{binding.store.class.name} state=#{binding.store.state} element=#{element}"
      window.animation_frame do
        value = binding.resolve(prior_state)
        # trace __FILE__, __LINE__, self, __method__, " :value=#{value} "
        set_attribute(element, attr, value)
      end
    end

    def set_content(element, content)
      # Browser::DOM::Node handles enumerables but we have to handle bindings
      if content.is_a?(Enumerable)
        content.each do |child|
          append_content(element, child)
        end
      else
        append_content(element, content)
      end
    end

    def append_content(element, content)
      content = sanitize_content(content, element)
      element << content if content
    end

    # Returns a Browser::DOM::Element
    def sanitize_content(content, element = nil)
      # trace __FILE__, __LINE__, self, __method__, " : content=#{content.class} element=#{element.class}"
      case content
        when Enumerable
          tag(:div, content)
        when node_class
          content
        when component_class
          content.root
        when tag_class
          content.to_element
        when binding_class
          if element
            # trace __FILE__, __LINE__, self, __method__, " : content=#{content.class} element=#{element.class}"
            resolve_bound_content(element, content)
          else
            fail "binding #{binding.where} must belong to parent element : cannot be root"
          end
        when NilClass
          nil
        else
          content.to_s
      end
    end

    # the resolved binding will become a child of the element
    def resolve_bound_content(element, binding)
      # trace __FILE__, __LINE__, self, __method__, " binding=#{binding}"
      element_bindings(element, init: true) << binding
      current_content = sanitize_content(binding.initial, element)
      binding.bind do |prior_state|
        # trace __FILE__, __LINE__, self, __method__, " : STARTING BINDING FOR #{binding.store.class} : #{binding.store.state}"
        old_content = current_content
        # trace __FILE__, __LINE__, self, __method__, " : UNBINDING OLD BINDINGS FOR #{binding.store.class} : #{binding.store.state}"
        unbind_descendant_bindings(old_content)
        # trace __FILE__, __LINE__, self, __method__, " : UNBOUND OLD BINDINGS FOR #{binding.store.class} : #{binding.store.state}"
        # trace __FILE__, __LINE__, self, __method__, " : RESOLVING NEW CONTENT FOR #{binding.store.class} : #{binding.store.state}"
        new_content = binding.resolve(prior_state)
        # trace __FILE__, __LINE__, self, __method__, " : RESOLVED NEW CONTENT FOR #{binding.store.class} : #{binding.store.state}"
        # trace __FILE__, __LINE__, self, __method__, " : SANITIZING NEW CONTENT FOR #{binding.store.class} : #{binding.store.state}"
        new_content = sanitize_content(new_content, element)
        # trace __FILE__, __LINE__, self, __method__, " : SANITIZED NEW CONTENT FOR #{binding.store.class} : #{binding.store.state}"
        # trace __FILE__, __LINE__, self, __method__, " : REPLACING BOUND CONTENT FOR #{binding.store.class} : #{binding.store.state}"
        replace_bound_content(element, new_content, old_content)
        # trace __FILE__, __LINE__, self, __method__, " : REPLACED BOUND CONTENT FOR #{binding.store.class} : #{binding.store.state}"
        current_content = new_content
        # trace __FILE__, __LINE__, self, __method__, " : FINISHED BINDING FOR #{binding.store.class} : "
      end
      current_content
    end

    def replace_bound_content(element, new_content, old_content)
      # trace __FILE__, __LINE__, self, __method__, "(element: #{element}, new_content: #{new_content}, old_content: #{old_content}"
      # trace __FILE__, __LINE__, self, __method__, ' ************** START WINDOW ANIMATION ON BINDING **************'
      window.animation_frame do
        if old_content
          if new_content
            element.replace_child(new_content, old_content)
          else
            element.remove_child(old_content)
          end
        else
          # trace __FILE__, __LINE__, self, __method__, " no old child!"
          if new_content
             element << new_content
          end
        end
      end
      # trace __FILE__, __LINE__, self, __method__, ' ************** END WINDOW ANIMATION ON BINDING **************'
      # trace __FILE__, __LINE__, self, __method__, " :=>"
    end

    def normalize_style(style)
      return {} unless style
      unless style.respond_to?(:to_h)
        raise TypeError, "#{__FILE__}[#{__LINE__}] : style #{style.class} must respond to :to_h"
      end
      result = {}
      style.to_h.each do |k, v|
        k = underscore_to_dash(k)
        result[k] = v.to_html
      end
      result
    end

    # Resolves 'on' events hash of actions.
    # Actions (hash values) may be procs or symbols.
    # If action is a symbol it is converted to method in self.
    # e.g.
    #   on: { change: :action }
    # becomes
    #   { change: => method(:action) }
    #
    def resolve_events(hash)
      result = {}
      hash.each do |k, v|
        k = strip_underscores(k)
        result[k] = Symbol === v || String === v ? method(v) : v
      end
      result
    end

    # Resolves data attributes in hash.
    # e.g.
    #   data: { key: 'xyz' }
    # becomes
    #   { 'data-key' => 'xyz }
    def resolve_data(hash)
      result = {}
      hash.each do |k, v|
        k = strip_underscores(k)
        v = v.to_html
        if k.index('data-') == 0
          result[k] = v
        else
          result["data-#{k}"] = v
        end
      end
      # puts "#{__FILE__}#[#{__LINE__}] : #{__method__}(#{hash}) => #{result}"
      result
    end

    # Resolves aria attributes.
    # e.g.
    #   aria: { expanded: false }
    # becomes
    #   { 'aria-expanded' => false }
    def resolve_aria(hash)
      result = {}
      hash.each do |k, v|
        k = strip_underscores(k)
        v = v.to_html
        if k.index('aria-') == 0
          result[k] = v
        else
          result[:"aria-#{k}"] = v
        end
      end
      result
    end

    def strip_underscores(s)
      s.include?('_') ? s.to_s.gsub(/_/, '') : s
    end

    def underscore_to_dash(s)
      s.include?('_') ? s.to_s.gsub(/_/, '-') : s
    end

    # unbind all bindings in the element and in all its descendants
    def unbind_descendant_bindings(element)
      if element && element.is_a?(element_class)
        # trace __FILE__, __LINE__, self, __method__, " : element=#{element}"
        descend(element) do |descendant|
          # trace __FILE__, __LINE__, self, __method__, " : element=#{element} descendant=#{descendant}"
          unbind_element_bindings(descendant)
        end
      else
        # trace __FILE__, __LINE__, self, __method__, " : cannot unbind descendants for #{element.class}"
      end
    end

    # unbind all bindings in the element
    def unbind_element_bindings(element)
      bindings = element_bindings(element)
      # trace __FILE__, __LINE__, self, __method__, " : element=#{element} bindings=#{bindings}"
      if bindings
        bindings.each do |binding|
          # trace __FILE__, __LINE__, self, __method__, " : element=#{element} binding=#{binding || 'NIL'}"
          binding.unbind
        end
        clear_bindings(element)
      end
    end

    # calling given block for node and all its descendants
    def descend(node, level: 0, &block)
      block.call(node)
      node.children.each do |child|
        descend(child, level: level + 1, &block)
      end
    end

    # get the bindings for an element
    # if init is true then initialize bindings to empty array none yet
    def element_bindings(element, init: false)
      bindings = element.data['robe::bindings']
      if init && bindings.nil?
        element.data['robe::bindings'] = bindings = []
      end
      bindings
    end

    def clear_bindings(element)
      element.data['robe::bindings'] = []
    end

  end
end end

$dom = Robe::Client::DOM

