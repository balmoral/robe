module Browser
  module DOM
    class Element < Node

      # Patch to improve performance of element creation.
      # Original does slow array searches and const_get's.
      # TODO: ensure we have covered all specially wrapped elements.
      # Worst that can happen is that we create an element
      # and will have methods missing when expecting special interface.
      def self.new(node)
        # puts "#{__FILE__}[#{__LINE__}] : self=#{self.name} node=#{`node.nodeName`}"
        if self == Element
          name = `node.nodeName`
          special = specials[name]
          if special
            # puts "#{__FILE__}[#{__LINE__}] : self=#{self.name} name=#{name}"
            special.new(node)
          else
            # puts "#{__FILE__}[#{__LINE__}] : self=#{self.name} name=#{name}"
            super
          end
        else
          super
        end
      end

      def self.specials
        @specials ||= {
          'INPUT'     => ::Browser::DOM::Element::Input,
          'IMAGE'     => ::Browser::DOM::Element::Image,
          'IMG'       => ::Browser::DOM::Element::Image,
          'TEMPLATE'  => ::Browser::DOM::Element::Template,
          'TEXTAREA'  => ::Browser::DOM::Element::Textarea
        }
      end
      
      def hidden?
        !!`#@native.hidden`
      end

      def focus
        `#@native.focus()`
      end

      def select
        `#@native.select()`
      end

      # added for select option
      def selected=(bool)
        `#@native.selected = bool`
      end

      # added for select option
      def checked=(bool)
        `#@native.checked = bool`
      end

      def offset_width
        `#@native.offsetWidth`
      end

      def client_width
        `#@native.clientWidth`
      end

      # return node data with given key/name
      def get_data(key)
        if value = self["data-#{key}"]
          value
        else
          %x{
            var data = #@native.$data;

            if (data === undefined) {
              return nil;
            }
            else {
              var value = #@native.$data[key];

              if (value === undefined) {
                return nil;
              }
              else {
                return value;
              }
            }
          }
        end
      end

      # node data[key] = value
      def set_data(key, value)
        unless defined?(`#@native.$data`)
          `#@native.$data = {}`
        end
        `#@native.$data[key] = value`
      end
      
      def get_style(name)
        %x{
          var result = #@native.style.getPropertyValue(#{name});

          if (result == null || result === "") {
            return nil;
          }

          return result;
        }
      end

      def set_style(name, value)
        `#@native.style.setProperty(#{name}, #{value.to_s}, "")`
      end

      def remove_style(name)
        `#@native.style.removeProperty(#{name})`
      end

      class Attributes
        attr_reader :namespace

        def initialize(element, options)
          @element   = element
          @native    = element.to_n
          @namespace = options[:namespace]
        end

        if Browser.supports?('Element.className') || Browser.supports?('Element.htmlFor')
          def [](name, options = {})
            if name == :class && Browser.supports?('Element.className')
              name = :className
            elsif name == :for && Browser.supports?('Element.htmlFor')
              name = :htmlFor
            end

            if namespace = options[:namespace] || @namespace
              `#@native.getAttributeNS(#{namespace.to_s}, #{name.to_s}) || nil`
            else
              `#@native.getAttribute(#{name.to_s}) || nil`
            end
          end

          def []=(name, value, options = {})
            if name == :class && Browser.supports?('Element.className')
              name = :className
            elsif name == :for && Browser.supports?('Element.htmlFor')
              name = :htmlFor
            end

            # BALMORAL - remove attribute if value is nil or false
            if namespace = options[:namespace] || @namespace
              if value
                `#@native.setAttributeNS(#{namespace.to_s}, #{name.to_s}, #{value})`
              else
                `#@native.removeAttributeNS(#{namespace.to_s}, #{name.to_s})`
              end
            else
              if value
                `#@native.setAttribute(#{name.to_s}, #{value.to_s})`
              else
                `#@native.removeAttribute(#{name.to_s})`
              end
            end
          end
        else
          def [](name, options = {})
            if namespace = options[:namespace] || @namespace
              `#@native.getAttributeNS(#{namespace.to_s}, #{name.to_s}) || nil`
            else
              `#@native.getAttribute(#{name.to_s}) || nil`
            end
          end

          def []=(name, value, options = {})
            # BALMORAL - remove attribute if value is nil or false
            if namespace = options[:namespace] || @namespace
              if value
                `#@native.setAttributeNS(#{namespace.to_s}, #{name.to_s}, #{value})`
              else
                `#@native.removeAttributeNS(#{namespace.to_s}, #{name.to_s})`
              end
            else
              # BALMORAL WAS `#@native.setAttribute(#{name.to_s}, #{value.to_s})`
              # screws up when content is Blob, etc
              if value
                `#@native.setAttribute(#{name.to_s}, #{value})`
              else
                `#@native.removeAttribute(#{name.to_s})`
              end
            end
          end
        end

        include Enumerable

        def each(&block)
          return enum_for :each unless block_given?

          @element.attribute_nodes.each {|attr|
            yield attr.name, attr.value
          }

          self
        end

        alias get []

        def has_key?(name)
          !!self[name]
        end

        def merge!(hash)
          hash.each {|name, value|
            self[name] = value
          }

          self
        end

        alias set []=
      end

    end
  end

end

