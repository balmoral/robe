require 'robe/common/util'
require 'robe/common/trace'
require 'robe/client/browser/dom/types'
require 'robe/client/browser/dom/aux/tag'
require 'robe/client/browser/dom/html/core_ext'
require 'robe/client/browser/dom/html/colors'
require 'robe/client/browser/dom/html/tags'
require 'robe/client/browser/dom/component'
require 'robe/client/browser/dom/aux/link'
require 'robe/client/browser/dom/aux/pdf'

module Robe
  module Client
    module Browser
      module DOM
        module_function

        # for every HTML tag define a method
        HTML_TAGS.each do |tag|
          define_method tag do |*args, &block|
            # puts "#{__FILE__}[#{__LINE__}] : #{self.class.name}##{tag}(#{args})"
            result = TAG_CLASS.new(tag, *args, &block)
            block.yield(result) if block
            result
          end
        end

        def window
          @window ||= Robe::Client::Browser.window
        end

        def document
          @document ||= Robe::Client::Browser.document
        end

        def [](id)
          document[id]
        end

        def clear(element)
          element.clear if element
          nil
        end

        # Returns a ::Browser::DOM::Element
        def tag(name, *args)
          # trace __FILE__, __LINE__, self, __method__, "(#{name}, #{args.class})"
          if name == :link || name == 'link'
            args = args.first
            fail 'link expects keyword args' unless args.robe_dom_type == HASH_TYPE
            LINK_CLASS.new(**args).root
          else
            # trace __FILE__, __LINE__, self, __method__, "(#{name}, #{args.class})"
            # turn args into hash
            if args.first.robe_dom_type == HASH_TYPE
              args = args.first
              content = args.delete(:content)
            else
              content = args
              args = { content: args }
            end
            if content.robe_dom_type == ARRAY_TYPE
              content = compact_flatten_array(content)
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
            css = attributes.delete(:css) # either :class or :css
            attributes[:class] = css if css
            # trace __FILE__, __LINE__, self, __method__, " : attributes=#{attributes})"
            namespace = attributes[:namespace] ? { namespace: attributes[:namespace] } : nil
            element = document.create_element(name, namespace)
            id = attributes[:id] # || "#{name}_#{Robe::Util.hex_id(6)}"
            element.id = id if id
            # trace __FILE__, __LINE__, self, __method__, " : element.id=#{element.id}"
            attributes.each do |attribute, value|
              # unless attributes == :css || attributes == :content # already dealt with
                ## trace __FILE__, __LINE__, self, __method__, " : attribute=#{attribute} value=#{value}) set"
                set_attribute(element, attribute, value)
                # trace __FILE__, __LINE__, self, __method__, " : attribute=#{attribute} value=#{value}) done"
              # end
            end
            # trace __FILE__, __LINE__, self, __method__, " : content=#{content.class} set"
            set_content(element, content)
            # trace __FILE__, __LINE__, self, __method__, " : content=#{content.class} done"
            element
          end
        end

        def compact_flatten_array(ary)
          if ary.find{|e| e.nil? || e.robe_dom_type == ARRAY_TYPE}
            compact = []
            ary.each do |e|
              if e
                if e.robe_dom_type == ARRAY_TYPE
                  compact.concat(compact_flatten_array(e))
                else
                  compact << e
                end
              end
            end
            compact
          else
            ary
          end
        end

        def hook(store, state_method = nil, *state_method_arg, where: nil, &hooked_block)
          HOOK_CLASS.new(store, state_method, *state_method_arg, where: where, &hooked_block)
        end

        # private api follows

        def set_attribute(element, attribute, value)
          # trace __FILE__, __LINE__, self, __method__, " value=#{value}" if value.robe_dom_type == HOOK_TYPE
          value = resolve_attribute(element, attribute, value)
          attribute_handler(attribute).call(element, attribute, value)
        end

        def attribute_handler(attribute)
          attribute_handlers[attribute] || default_attribute_handler
        end

        def attribute_handlers
          @attribute_handlers ||= {
            style: ->(element, _attribute, value) {
              if value
                set_style(element, value)
              end
            },
            class: ->(element, attribute, value) {
              if value
                value = if value.robe_dom_type == ARRAY_TYPE
                  value.map{|e| underscore_to_dash(e)}.join(' ')
                elsif value.robe_dom_type == STRING_TYPE
                  underscore_to_dash(value)
                else
                  fail "illegal css/class attribute value #{value.class}"
                end
              end
              element[attribute] = value
            },
            on: ->(element, _attribute, value) {
              resolve_events(value).each do |event, callback|
                element.on(event, &callback)
              end
            },
            data: ->(element, _attribute, value) {
              resolve_data(value).each do |data_key, data_value|
                # trace __FILE__, __LINE__, self, __method__, " data_key=#{data_key} data_value=#{data_value}"
                element[data_key] = resolve_attribute(element, data_key, data_value)
              end
            :aria
              resolve_aria(value).each do |aria_key, aria_value|
                element[aria_key] = resolve_attribute(element, aria_key, aria_value)
              end
            },
            selected: ->(element, _attribute, value) {
              element.selected = value
            },
            checked: ->(element, _attribute, value) {
              element.checked = value
            },
            #
            autocomplete: ->(element, _attribute, value) {
              element.autocomplete = !!value
            },
            # https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XUL/Attribute/disabled
            enabled: ->(element, _attribute, value) {
              if value
                element.remove_attr(:disabled)
              else
                element[:disabled] = 'disabled'
              end
            },
            # https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XUL/Attribute/disabled
            disabled: ->(element, _attribute, value) {
              if value
                element[:disabled] = 'disabled'
              else
                element.remove_attr(:disabled)
              end
            },
            props: ->(element, _attribute, value) {
              value.each do |p, v|
                element[p] = v
              end
            },
            properties: ->(element, _attribute, value) {
              value.each do |p, v|
                element[p] = v
              end
            },
            scope: ->(element, _attribute, value) {
              element.scope = value.to_s
            }
          }
        end

        def default_attribute_handler
          @default_attribute_handler ||= ->(element, attribute, value) {
            if value
              attribute = strip_underscores(attribute)
              unless attribute == :value
                if value.robe_dom_type == STRING_TYPE
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
          if value.robe_dom_type == HOOK_TYPE
            # trace __FILE__, __LINE__, self, __method__, " : hook=#{value}"
            resolve_attribute_hook(element, attr, value)
          else
            value
          end
        end

        # the resolved hook will become an attribute of the element
        def resolve_attribute_hook(element, attr, hook)
          # trace __FILE__, __LINE__, self, __method__, " hook=#{hook}"
          element.hooks(element, init: true) << hook
          hook.activate do |prior_state|
            update_element_attribute(hook, prior_state, element, attr)
          end
          hook.value # initial value from the hooked store's state
        end

        def update_element_attribute(hook, prior_state, element, attr)
          # trace __FILE__, __LINE__, self, __method__, " :action=#{action} store=#{hook.store.class.name} state=#{hook.store.state} element=#{element}"
          window.animation_frame do
            value = hook.value(prior_state)
            # trace __FILE__, __LINE__, self, __method__, " :value=#{value} "
            set_attribute(element, attr, value)
          end
        end

        def set_content(element, content)
          if content.robe_dom_type == ARRAY_TYPE
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

        # Returns a String or Browser::DOM::Element or Bowser::Element.
        def sanitize_content(content, parent_element, coerce_to_element: false)
          # trace __FILE__, __LINE__, self, __method__, " : content=#{content.class} element=#{element.class}"
          handler = sanitize_content_handlers[content.robe_dom_type]
          unless handler
            fail "no known handler for content.class=#{content.class} content.robe_dom_type=#{content.robe_dom_type}"
          end
          handler.call(content, parent_element, coerce_to_element)
        end

        def sanitize_content_handlers
          unless @sanitize_content_handlers
            @sanitize_content_handlers = []
            @sanitize_content_handlers[DEFAULT_TYPE] = ->(content, _parent_element,coerce_to_element) {
              coerce_to_element ? tag(:span, content) : content.to_s
            }
            @sanitize_content_handlers[STRING_TYPE] = @sanitize_content_handlers[DEFAULT_TYPE]
            @sanitize_content_handlers[NIL_TYPE] = ->(_nil, _parent_element, _coerce_to_element) {
              nil
            }
            @sanitize_content_handlers[ARRAY_TYPE] = ->(enum, _parent_element, _coerce_to_element) {
              tag(:div, enum)
            }
            @sanitize_content_handlers[HASH_TYPE] = @sanitize_content_handlers[ARRAY_TYPE]
            @sanitize_content_handlers[WRAP_TYPE] = ->(node, _parent_element, _coerce_to_element) {
              node
            }
            @sanitize_content_handlers[HOOK_TYPE] = ->(hook, parent_element, _coerce_to_element) {
              if parent_element
                # trace __FILE__, __LINE__, self, __method__, " : content=#{content.class} element=#{element.class}"
                resolve_hooked_content(parent_element, hook)
              else
                fail "hook #{hook.where} must belong to parent element : cannot be root"
              end
            }
            @sanitize_content_handlers[TAG_TYPE] = ->(tag, _parent_element, _coerce_to_element) {
              tag.to_element
            }
            @sanitize_content_handlers[COMPONENT_TYPE] = ->(component, _parent_element, _coerce_to_element) {
              component.root
            }
          end
          @sanitize_content_handlers
        end

        # the resolved hook will become a child of the element
        def resolve_hooked_content(element, hook)
          # trace __FILE__, __LINE__, self, __method__, " hook=#{hook}"
          element.hooks(init: true) << hook
          current_content = hook.value && sanitize_content(hook.value, element, coerce_to_element: true)
          hook.activate do |prior_state|
            old_content = current_content
            new_content = hook.value(prior_state)
            new_content = sanitize_content(new_content, element, coerce_to_element: true) if new_content
            replace_hooked_content(element, new_content, old_content)
            current_content = new_content
          end
          current_content
        end

        def replace_hooked_content(element, new_content, old_content)
          # trace __FILE__, __LINE__, self, __method__, "(element: #{element}, new_content: #{new_content.class}:#{new_content}, old_content: #{old_content.class}:#{old_content}"
          # trace __FILE__, __LINE__, self, __method__, ' ************** START WINDOW ANIMATION ON HOOK **************'
          window.animation_frame do
            # trace __FILE__, __LINE__, self, __method__, "(element: #{element.class}:#{element}, new_content: #{new_content.class}:#{new_content}, old_content: #{old_content.class}:#{old_content}"
            if old_content
              if new_content
                # trace __FILE__, __LINE__, self, __method__, "(element: #{element.class}:#{element}, new_content: #{new_content.class}:#{new_content}, old_content: #{old_content.class}:#{old_content}"
                element.replace_child(new_content, old_content)
              else
                element.remove_child(old_content)
              end
            else
              # trace __FILE__, __LINE__, self, __method__, " no old child!"
              element << new_content if new_content
            end
          end
          # trace __FILE__, __LINE__, self, __method__, ' ************** END WINDOW ANIMATION ON HOOK **************'
          # trace __FILE__, __LINE__, self, __method__, " :=>"
        end

        def set_style(element, style)
          style.to_h.each do |key, value|
            name = underscore_to_dash(key)
            element.set_style(name, value.to_html)
          end
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
          hash.each do |event, callback|
            event = strip_underscores(event)
            result[event] = if callback.robe_dom_type == STRING_TYPE
              method(callback.to_sym)
            else
              callback
            end
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
          # s.include?('_') ? s.to_s.gsub(/_/, '') : s
          # `s.indexOf('_') == -1` ? s : `s.replace(/_/g, '')`
          `s.replace(/_/g, '')`
        end

        def underscore_to_dash(s)
          # s.include?('_') ? s.to_s.gsub(/_/, '-') : s
          # `s.indexOf('_') == -1` ? s : `s.replace(/_/g, '-')`
          `s.replace(/_/g, '-')`
        end

      end
    end
  end
end

