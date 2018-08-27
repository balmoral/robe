require 'robe/common/trace'
require 'robe/common/state'

# GLOBAL ATTRIBUTES
#
# Global attributes are attributes common to all HTML elements;
# they can be used on all elements, though the attributes may
# have no effect on some elements.
# https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes
#
# We currently support:
#   Ruby                          Html
#   ----                          ----
#   class: 'xyz'                  class="xyz"
#   data: {
#     abc: 'xyz'                  data-abc="xyz"
#     def: 'uvw'                  data-def="uvw"
#   }
#   draggable: true               draggable=true
#   hidden: true                  hidden=true
#   id: 'Xyz_1'                   id="Xyz_1"
#   style: {
#     background_color: 'blue',   style="background-color: blue"
#     ...
#   }
#   tab_index: 1                  tabindex=1
#   title: 'Title'                title="Title"
#
# Unsupported global attributes can be specified by using
# the standard html attribute name as the key, with the value
# in standard html format.
#
# TODO: implement all global attributes.
#
# ===
#
# ALL ATTRIBUTES
# https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes
#
# Unsupported non-global attributes can be specified by using
# the standard html attribute name as the key, with the value
# in standard html format.
#
# ===
#
# EVENTS
# https://developer.mozilla.org/en-US/docs/Web/Events
#
# Events are specified in on: {}.

# Event names can have underscores if preferred - these
# will be stripped as required.
#
# Events handlers are procs which may accept an event argument.
#
#   Ruby                          JS
#   ----                          ----
#   on: {
#     before_print: method(bp),   element.onbeforeprint=bp
#   }
#
# ===
#
# ARIA
# https://developer.mozilla.org/en-US/docs/Web/Accessibility/An_overview_of_accessible_web_applications_and_widgets
#
#   Ruby                          Html
#   ----                          ----
#   role: :tab_panel              role="tabpanel"
#   aria: {
#     hidden: true,               aria-hidden="true"
#     labelled_by: 'ch1Tab'       aria-labelled_by="ch1Tab"
#   }
#


module Robe
  module Client
    module Browser
      module DOM
        class Component
          include Robe::Client::Browser
          include Robe::Client::Browser::DOM
          include Robe::Client::Browser::DOM::HTML::Colors

          def initialize
          end

          # Returns the root Browser::DOM::Element
          def root
            unless @root
              # trace __FILE__, __LINE__, self, __method__
              @root = render
              if @root.is_a?(Robe::State::Binding) || @root.is_a?(Enumerable)
                @root = tag(:div, @root)
              end
              @root = sanitize_content(@root)
            end
            @root
          end

          def clear
            @root = DOM.clear(@root)
          end

          # Returns a Browser::DOM::Element.
          # Default render method for stubbing.
          # Subclasses should override.
          def render
            div[]
          end

          # Appends rendered component to the document body
          # when document is ready.
          def append_to_body
            document.ready do
              document.body << root.to_n
            end
          end

          def dom
            Robe.dom
          end

          def document
            Robe.document
          end

          def window
            Robe.window
          end

          def body
            document.body
          end

          # will be nil if DOM used without Client::App
          def app
            Robe.app
          end

          # may be nil if DOM used without Client::App
          def router
            app.router if app
          end

          # will be nil if DOM used without Client::App
          def route
            router.route if router
          end

          # will be nil if DOM used without Client::App
          def params
            route.params if route
          end

        end
      end
    end
  end
end

