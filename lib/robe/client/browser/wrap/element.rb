require 'robe/common/util/unicode'

module Robe; module Client; module Browser; module Wrap
  class Element
    include Native
    include EventTarget
    include NativeFallback
    include Robe::Unicode
    
    SPECIAL_EVENTS = %i(removing)

    def initialize(native)
      super
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


    # get the hooks for an element
    # if init is true then initialize hooks to empty array none yet
    def hooks(init: false)
      private_hooks(init: init)
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

    def hide
      `#@native.hide`
    end
    
    # enumerates each native child
    def each_native_child(target = nil, &block)
      target ||= self
      target = native?(target) ? target : target.to_n
      %x{
        var children = target.children;
        for(var i = 0; i < children.length; i++) {
          #{block.call(`children[i]`)};
        }
      }
    end

    # enumerates each child as a Wrap::Element
    def each_child(&block)
      each_native_child do |e|
        block.call(self.class.new(e))
      end
    end

    # returns an array of Wrap::Element's my children
    def children
      [].tap { |result|
        each_child { |e| result << e }
      }
    end

    # Returns true if given element is a descendant of this element.
    def contains?(node)
      n = native?(node) ? node : node.to_n
      `#@native.contains(n)`
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
    def get_data(key, native_target = nil)
      target = native_target || @native
      if value = self["data-#{key}"]
        value
      else
        %x{
          var data = target.$data;

          if (data === undefined) {
            return nil;
          }
          else {
            var value = target.$data[key];

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
    def set_data(key, value, native_target = nil)
      target = native_target || @native
      unless defined?(`target.$data`)
        `target.$data = {}`
      end
      `target.$data[key] = value`
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

    # https://developer.mozilla.org/en-US/docs/Web/Security/Securing_your_site/Turning_off_form_autocompletion
    def autocomplete=(bool)
      unless bool
        # won't work on firefox
        `#@native.autocomplete = "new-password"`
      end
    end

    def scope=(s)
      `#@native.scope = s`
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
        each_native_child.each do |child|
          remove_child(child)
        end
      end
      self
    end

    def remove_child(child)
      about_to_remove_child(child)
      `#@native.removeChild(#{native?(child) ? child : child.to_n})`
      self
    end

    def replace_child(new_child, old_child)
      about_to_remove_child(old_child)
      parent = to_n
      new_child = new_child.to_n unless native?(new_child)
      old_child = old_child.to_n unless native?(old_child)
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

    # requires jquery and bootstrap.js - will fail otherwise
    def check_jquery
      %x(
        if (typeof jQuery === 'undefined') {
          throw new Error('jQuery js not loaded');
        }
      )
    end

    def check_bootstrap
      check_jquery
      %x(
        if (typeof(jQuery.fn.tooltip) === 'undefined') {
          throw new Error('Bootstrap js not loaded');
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
    def tooltip(arg)
      if arg.is_a?(String)
        arg = {
          title: arg,
          placement: 'auto',
          trigger: 'hover focus',
        }
      end
      arg['title'] ||= '?'
      arg['title'] = arg['title'].gsub(' ', unicode(:no_break_space)) # to stop wrapping on spaces
      arg['title'] = arg['title'].gsub('\n', ' ') # to let caller force wrapping on newlines
      arg['container'] = to_n
      arg['template'] = '<div class="tooltip" role="tooltip"><div class="arrow"></div><div class="tooltip-inner"></div></div>'
      check_bootstrap
      `$(#@native).tooltip(#{arg.to_n})`
    end

    def popover(arg)
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

    # Call given block for native element and all its
    # native descendants. Deepest descendants called first.
    def descend(target, level: 0, &block)
      each_native_child(target) do |native_child|
        descend(native_child, level: level + 1, &block)
      end
      block.call(target)
    end

    def about_to_remove_child(child)
      descend(child) do |native_descendant|
        clear_hooks(native_descendant)
        notify_special_event(:removing, native_descendant)
        clear_special_event_observers(native_descendant)
      end
    end

    OBSERVERS_DATA_KEY = 'robe::event::observers'

    def notify_special_event(event, native_target = nil)
      observers = get_data(OBSERVERS_DATA_KEY, native_target)
      if observers
        observers = observers[event.to_sym]
        if observers
          observers.each do |observer|
            observer.call
          end
        end
      end
    end

    def clear_special_event_observers(native_target = nil)
      set_data(OBSERVERS_DATA_KEY, nil, native_target)
    end

    HOOKS_DATA_KEY = 'robe::hooks'

    # get the hooks for an element
    # if init is true then initialize hooks to empty array none yet
    def private_hooks(native_target: nil, init: false)
      native_target ||= @native
      hooks = get_data(HOOKS_DATA_KEY, native_target)
      if init && hooks.nil?
        set_data(HOOKS_DATA_KEY, hooks = [], native_target)
      end
      hooks
    end

    def clear_hooks(native_target = nil)
      hooks = private_hooks(native_target: native_target)
      # trace __FILE__, __LINE__, self, __method__, " : element=#{element} hooks=#{hooks}"
      if hooks
        hooks.each do |hook|
          # trace __FILE__, __LINE__, self, __method__, " : element=#{element} hook=#{hook || 'NIL'}"
          hook.deactivate
        end
      end
      set_data(HOOKS_DATA_KEY, [], native_target)
    end

    # might be slow
    def nativize(target)
      native?(target) ? target : target.to_n
    end

    def map_element_set(ary)
      ary.flatten.map { |x| Element.new(Native.convert(x)) }.uniq
    end
  end
end end end end
