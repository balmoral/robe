module Robe; module Client; module Browser; module Wrap
  class Document < Wrap::Element

    def initialize
      super(`document`)
    end

    def body
      @body ||= Element.new(`#@native.body`)
    end

    def URL
      `#@native.URL`
    end

    # @!attribute [r] cookies
    # @return [Cookies] the cookies for the document
    def cookies
      Cookies.new(@native) if defined?(`#@native.cookie`)
    end

    # Get the first element matching the given ID, CSS selector or XPath.
    #
    # @param what [String] ID, CSS selector or XPath
    #
    # @return [Element?] the first matching element
    def [](what)
      %x{
        var result = #@native.getElementById(what);

        if (result) {
          return #{Element.new(`result`)};
        }
      }
      css(what).first || xpath(what).first
    end

    alias at []

    # Create a new element for the document.
    #
    # @param name [String] the node name
    # @param options [Hash] optional `:namespace` name
    #
    # @return [Wrap::Element]
    def create_element(name, options = nil)
      if ns = options && options[:namespace]
        Element.new(`#@native.createElementNS(#{ns}, #{name})`)
      else
        Element.new(`#@native.createElement(name)`)
      end
    end

    # Returns a ::Wrap::Element.
    def active_element
      el = `#@native.activeElement()`
      Element.new(el) if el
    end

    # added by @balmoral
    # returns Element or nil
    def get_element_by_id(id)
      el = `#@native.getElementById(id)`
      if `el === null`
        nil
      else
        Element.new(el)
      end
    end

    # added by @balmoral
    # convenience if only one element required
    # returns Element or nil
    def get_element_by_name(name)
      get_elements_by_name(name).first
    end

    # added by @balmoral
    # returns array of Element's
    def get_elements_by_name(name)
      nodes = `#@native.getElementsByName(name)`
      `nodes.length`.times.map { |i| Element.new(`nodes[i]`) }
    end

  end

  module_function

  def document
    @document ||= Wrap::Document.new
  end
end end end end
