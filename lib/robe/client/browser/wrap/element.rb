module Robe; module Client; module Browser; module Wrap
  class Element
    include EventTarget
    include NativeFallback

    SPECIAL_EVENTS = %i(removing)

    def initialize(native)
      @native = native
    end

    def on(event, &callback)
      if SPECIAL_EVENTS.include?(event)
        observers = get_data(OBSERVERS_DATA_KEY)
        set_data(OBSERVERS_DATA_KEY, observers = {}) unless observers
        (observers[event.to_sym] ||= []) << callback
      else
        super # EventTarget
      end
    end
    
    OBSERVERS_DATA_KEY = 'robe::event::observers'

    def notify_special_event(event, element = nil)
      observers = (element || self).get_data(OBSERVERS_DATA_KEY)
      if observers
        observers = observers[event.to_sym]
        if observers
          observers.each do |observer|
            observer.call
          end
        end
      end
    end

    def clear_special_event_observers(element = nil)
      (element || self).set_data(OBSERVERS_DATA_KEY, nil)
    end

    BINDINGS_DATA_KEY = 'robe::bindings'

    # get the bindings for an element
    # if init is true then initialize bindings to empty array none yet
    def bindings(element = nil, init: false)
      element ||= self
      bindings = element.get_data(BINDINGS_DATA_KEY)
      if init && bindings.nil?
        element.set_data(BINDINGS_DATA_KEY, bindings = [])
      end
      bindings
    end

    def clear_bindings(element = nil)
      element ||= self
      bindings = bindings(element)
      # trace __FILE__, __LINE__, self, __method__, " : element=#{element} bindings=#{bindings}"
      if bindings
        bindings.each do |binding|
          # trace __FILE__, __LINE__, self, __method__, " : element=#{element} binding=#{binding || 'NIL'}"
          binding.unbind
        end
      end
      (element || self).set_data(BINDINGS_DATA_KEY, [])
    end

    # @!attribute id
    # @return [String?] the ID of the element
    def id
      %x{
        var id = #@native.id;

        if (id === "") {
          return nil;
        }
        else {
          return id;
        }
      }
    end

    def id=(value)
      `#@native.id = #{value.to_s}`
    end

    def inner_dom=(node)
      clear
      append(node)
    end

    def inner_html
      `#@native.innerHTML`
    end

    def inner_html=(html)
      `#@native.innerHTML = html`
    end

    def children
      elements = []
      %x{
        var children = #@native.children;
        for(var i = 0; i < children.length; i++) {
          elements[i] = #{Element.new(`children[i]`)};
        }
      }
      elements
    end

    # from opal-browser Browser::DOM::Element:Attributes
    if Wrap::Browser.supports?('Element.className') || Wrap::Browser.supports?('Element.htmlFor')
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

        if namespace = options[:namespace] || @namespace
          `#@native.setAttributeNS(#{namespace.to_s}, #{name.to_s}, #{value})`
        else
          `#@native.setAttribute(#{name.to_s}, #{value.to_s})`
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
        if namespace = options[:namespace] || @namespace
          `#@native.setAttributeNS(#{namespace.to_s}, #{name.to_s}, #{value})`
        else
          `#@native.setAttribute(#{name.to_s}, #{value.to_s})`
        end
      end
    end

    alias attr []
    alias attribute []
    alias set []=
    alias set_attribute []=

    def remove_attr(name)
      `#@native.getAttribute(#{name.to_s})`
    end

    alias remove_attribute remove_attr
    
    if Browser.supports? 'Query.css'
      def css(path)
        map_element_set Native::Array.new(`#@native.querySelectorAll(path)`)
      rescue
        []
      end
    elsif Browser.loaded? 'Sizzle'
      def css(path)
        map_element_set Native::Array.new(`Sizzle(path, #@native)`)
      rescue
        []
      end
    else
      # Query for children matching the given CSS selector.
      #
      # @param selector [String] the CSS selector
      #
      # @return [NodeSet]
      def css(selector)
        raise NotImplementedError, 'query by CSS selector unsupported'
      end
    end

    if Browser.supports?('Query.xpath') || Browser.loaded?('wicked-good-xpath')
      if Browser.loaded? 'wicked-good-xpath'
        `wgxpath.install()`
      end

      def xpath(path)
        map_element_set Native::Array.new(
          `(#@native.ownerDocument || #@native).evaluate(path,
             #@native, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null)`,
          get:    :snapshotItem,
          length: :snapshotLength
        )
      rescue
        []
      end
    else
      # Query for children matching the given XPath.
      #
      # @param path [String] the XPath
      #
      # @return [NodeSet]
      def xpath(path)
        raise NotImplementedError, 'query by XPath unsupported'
      end
    end

    # return element data with given key/name
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

    # element data[key] = value
    def set_data(key, value)
      unless defined?(`#@native.$data`)
        `#@native.$data = {}`
      end
      `#@native.$data[key] = value`
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

    def hidden?
      !!`#@native.hidden`
    end

    def value
      `#@native.value`
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

    def empty?
      `#@native.children.length === 0`
    end

    def clear
      if %w(input textarea).include?(type)
        `#@native.value = null`
      else
        children.each do |child|
          remove_child(child)
        end
      end
      self
    end

    # Call given block for node and all its descendants.
    # Deepest descendants called first.
    def descend(element, level: 0, &block)
      element.children.each do |child|
        descend(child, level: level + 1, &block)
      end
      block.call(element)
    end

    def about_to_remove_child(child)
      child = self.class.new(child) if native?(child)
      descend(child) do |descendant|
        clear_bindings(descendant)
        notify_special_event(:removing, descendant)
        clear_special_event_observers(descendant)
      end
    end

    def remove_child(child)
      about_to_remove_child(child)
      `#@native.removeChild(child.native ? child.native : child)`
    end

    def replace_child(new_child, old_child)
      about_to_remove_child(old_child)
      parent = to_n
      new_child = new_child.to_n
      old_child = old_child.to_n
      `parent.replaceChild(new_child, old_child)`
      self
    end

    def type
      `#@native.nodeName`.downcase
    end

    def append(node)
      if Opal.respond_to?(node, :each)
        node.each { |n| self << n }
      else
        unless native?(node)
          node = if node.is_a?(String)
            `#@native.ownerDocument.createTextNode(node)`
          else
            Native.convert(node)
          end
        end
        `#@native.appendChild(node)`
      end
      self
    end

    alias << append

    # Form input methods
    def checked?
      `!!#@native.checked`
    end

    # Convenience for when you only need a single file
    def file
      files.first
    end

    def files
      FileList.new(`#@native.files`)
    end

    # Fall back to native properties.
    def method_missing(message, *args, &block)
      # undefined check added by @balmoral
      if `typeof(#@native) == 'undefined'`
        fail "#{__FILE__}[#{__LINE__}]: @native is undefined"
      end
      super # NativeFallback
    end

    def to_n
      @native
    end

    # requires jquery and bootstrap.js - will fail otherwise
    def check_jquery
      %x(
        if (typeof jQuery === 'undefined') {
          throw new Error('Bootstrap\'s JavaScript requires jQuery');
        }
      )
    end

    def check_bootstrap
      %x(
        if (typeof($.fn.tooltip) === 'undefined') {
          throw new Error('Bootstrap.js not loaded');
        }
      )
    end

    # TODO: replicate this for all Bootstrap js features
    # TODO: refactor all bootstrap stuff to separate module
    # arg may be:
    # 0. nil - attaches tooltip to node
    # 1. hash of options and attaches tooltip to node
    # 2. 'show'
    # 3. 'hide'
    # 4. 'toggle'
    # 4. 'destroy'
    # see http://getbootstrap.com/javascript/#tooltips
    def tooltip(arg=nil)
      if arg.is_a?(String)
        arg = {
          title: arg,
          trigger: 'hover focus',
        }
      end
      check_bootstrap
      `$(#@native).tooltip(#{arg.to_n})`
    end

    def popover(arg=nil)
      if arg.is_a?(String)
        arg = {
          title: arg,
          trigger: 'hover focus',
        }
      end
      check_bootstrap
      `$(#@native).popover(#{arg.to_n})`
    end

    private

    def map_element_set(ary)
      ary.flatten.map { |x| Element.new(Native.convert(x)) }.uniq
    end
  end
end end end end
