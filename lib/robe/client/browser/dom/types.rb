require 'robe/common/util'
require 'robe/common/trace'
require 'robe/client/browser/dom/aux/tag'
require 'robe/client/browser/dom/html/core_ext'
require 'robe/client/browser/dom/html/colors'
require 'robe/client/browser/dom/html/tags'
require 'robe/client/browser/dom/component'
require 'robe/client/browser/dom/aux/link'
require 'robe/client/browser/dom/aux/pdf'

module Robe
  module Client; module Browser
    module DOM
      DEFAULT_TYPE    = 0
      NIL_TYPE        = 1
      STRING_TYPE     = 2 # also for Symbol
      ARRAY_TYPE      = 3
      HASH_TYPE       = 4
      WRAP_TYPE       = 5 # Robe::Client::Browser::Wrap::Element
      BINDING_TYPE    = 6
      TAG_TYPE        = 7
      COMPONENT_TYPE  = 8

      BINDING_CLASS   = Robe::State::Binding
      ELEMENT_CLASS   = Robe::Client::Browser::Wrap::Element
      TAG_CLASS       = Robe::Client::Browser::DOM::Tag
      LINK_CLASS      = Robe::Client::Browser::DOM::Link
      HTML_TAGS       = Robe::Client::Browser::DOM::HTML::TAGS + ['link']
    end
  end end

  module_function

  @dom = Robe::Client::Browser::DOM

  def dom
    @dom
  end
end

# Some kludgy but effective monkey patching
# to speed up resolving and sanitizing dom
# content and attributes.
# Each possible content/attribute class
# specifies it's class as an integer value.
# This let's us avoid much slower is_a? calls
# and/or class-based case statements.

class Object
  def robe_dom_type
    Robe.dom::DEFAULT_TYPE
  end
end

class NilClass
  def robe_dom_type
    Robe.dom::NIL_TYPE
  end
end

class String
  def robe_dom_type
    Robe.dom::STRING_TYPE
  end
end

class Symbol
  def robe_dom_type
    Robe.dom::STRING_TYPE
  end
end

module Enumerable
  def robe_dom_type
    Robe.dom::ARRAY_TYPE
  end
end

class Array
  def robe_dom_type
    Robe.dom::ARRAY_TYPE
  end
end

class Hash
  def robe_dom_type
    Robe.dom::HASH_TYPE
  end
end

module Robe; module Client; module Browser; module Wrap; class Element
  def robe_dom_type
    Robe.dom::WRAP_TYPE
  end
end end end end end

module Robe; module State; class Binding
  def robe_dom_type
    Robe.dom::BINDING_TYPE
  end
end end end

module Robe; module Client; module Browser; module DOM; class Tag
  def robe_dom_type
    Robe.dom::TAG_TYPE
  end
end end end end end

module Robe; module Client; module Browser; module DOM; class Component
  def robe_dom_type
    Robe.dom::COMPONENT_TYPE
  end
end end end end end



