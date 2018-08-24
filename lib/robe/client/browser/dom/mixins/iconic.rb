# expects to be include'd in a Robe::Client::Component

require 'robe/common/util'
require 'robe/common/trace'
require 'robe/client/browser/dom/mixins/list_item_link'
require 'robe/client/browser/dom/mixins/dropdown_item_link'

# TODO: Iconic is a mess of a module, needs big refactor

module Robe
  module Client
    module Browser
      module DOM
        module Iconic
          extend Robe::Util
          include Robe::Util
          include Robe::Client::Browser::DOM::ListItemLink
          extend Robe::Client::Browser::DOM::ListItemLink
          include Robe::Client::Browser::DOM::DropdownItemLink
          extend Robe::Client::Browser::DOM::DropdownItemLink

          module_function

          # e.g. attributes = {
          #   src: nil,
          #   width: 16.px,
          #   height: 16.px
          # }
          # https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img
          # width and height can be specified for image
          def image_tag(**args)
            args[:width] ||= 16.px
            args[:height] ||= 16.px
            img.props(**args)
          end

          # if attributes contain image attributes set icon to '#image'
          # otherwise attributes should be valid kwargs to tag
          def icon(icon_type, attributes: nil, callback: nil, tooltip: nil, popover: nil)
            attributes ||= {}
            style = {
              text_align: 'center',
              cursor: 'pointer',
              # color: 'inherit',
              # background_color: 'inherit',
            }
            image, css = nil, ''
            if icon_type.to_s == '#image'
              css = attributes.delete(:css) || attributes.delete(:class) || ''
              image = image_tag(attributes)
            else
              css = iconify(icon_type)
              if (arg_css = attributes.delete(:css) || attributes.delete(:class))
                css = css + ' ' + arg_css
              end
              if (arg_style = attributes[:style])
                # arg style overrides any defaults
                style = style.merge(arg_style)
              end
            end
            params = attributes.merge(
              css: css,
              style: style,
              on: (attributes[:on] || {}).merge(callback ? { click: callback } : {}),
              content: image
            )
            # trace __FILE__, __LINE__, self, __method__, " : params = #{params}"
            icon = tag(:span, **params)
            if tooltip
              if tooltip.is_a?(String)
                tooltip = {
                  animation: true,
                  title: tooltip,
                  placement: 'auto',
                  trigger: 'hover focus',
                  # delay: { hide: '200' }
                }
              end
              # trace __FILE__, __LINE__, self, __method__, " : icon.id = #{icon.id}"
              # tooltip[:container] = icon.id unless tooltip[:container]
              icon.tooltip(tooltip)
            elsif popover
              if popover.is_a?(String)
                popover = { title: popover, placement: 'right', trigger: 'hover focus'}
              end
              popover[:container] ='body' unless popover[:container]
              icon.popover(popover)
            end
            # trace __FILE__, __LINE__, self, __method__, " : icon => #{icon}"
            icon
          end

          def icon_with_link(icon_name, href, icon_attributes: nil, link_attributes: nil, tooltip: nil, popover: nil)
            # trace __FILE__, __LINE__, self, __method__, " : icon_name=#{icon_name} href=#{href}"
            params = { href: href }
            if link_attributes
              params = merge_attributes(link_attributes, params)
            end
            params[:content] = icon(icon_name, attributes: icon_attributes, tooltip: tooltip, popover: popover)
            tag(:link, **params)
          end

          def plus_sign_icon_link(href, icon_attributes: nil, link_attributes: nil, tooltip: nil, popover: nil)
            # trace __FILE__, __LINE__, self, __method__, " : href = #{href}"
            _icon_attributes = {
              style: {
                color: 'lightgreen',
              }
            }
            if icon_attributes
              # argument takes precedence
              _icon_attributes = merge_attributes(_icon_attributes, icon_attributes)
            end
            icon_with_link(
              'plus-sign',
              href,
              icon_attributes: _icon_attributes,
              link_attributes: link_attributes,
              tooltip: tooltip,
              popover: popover
            )
          end

          def transfer_icon(callback: nil, attributes: nil, tooltip: nil, popover: nil)
            icon(
              :transfer,
              callback: callback,
              attributes: attributes,
              tooltip: tooltip,
              popover: popover
            )
          end

          def flash_icon(callback: nil, attributes: nil, tooltip: nil, popover: nil)
            icon(
              :flash,
              callback: callback,
              attributes: attributes,
              tooltip: tooltip,
              popover: popover
            )
          end

          def download_icon(callback: nil, attributes: nil, tooltip: nil, popover: nil)
            icon(
              :download,
              callback: callback,
              attributes: attributes,
              tooltip: tooltip,
              popover: popover
            )
          end

          def upload_icon(callback: nil, attributes: nil, tooltip: nil, popover: nil)
            icon(
              :upload,
              callback: callback,
              attributes: attributes,
              tooltip: tooltip,
              popover: popover
            )
          end

          def import_icon(callback: nil, attributes: nil, tooltip: nil, popover: nil)
            icon(
              :import,
              callback: callback,
              attributes: attributes,
              tooltip: tooltip,
              popover: popover
            )
          end

          def export_icon(callback: nil, attributes: nil, tooltip: nil, popover: nil)
            icon(
              :export,
              callback: callback,
              attributes: attributes,
              tooltip: tooltip,
              popover: popover
            )
          end

          def remove_sign_icon(callback: nil, attributes: nil, tooltip: nil, popover: nil)
            _attributes = {
              style: {
                color: 'red',
              }
            }
            if attributes
              # argument takes precedence
              _attributes = merge_attributes(_attributes, attributes)
            end
            icon(
              :remove_sign,
              callback: callback,
              attributes: _attributes,
              tooltip: tooltip,
              popover: popover
            )
          end

          def refresh_icon(callback: nil, attributes: nil, tooltip: nil, popover: nil)
            icon(
              :refresh,
              callback: callback,
              attributes: merge_attributes({ style: { color: 'inherit' } }, attributes),
              tooltip: tooltip,
              popover: popover
            )
          end

          def reset_icon(callback: nil, attributes: nil, tooltip: nil, popover: nil)
            icon(
              :refresh, # :adjust, # :step_backward,
              callback: callback,
              attributes: merge_attributes({ style: { color: 'inherit' } }, attributes),
              tooltip: tooltip,
              popover: popover
            )
          end

          def save_icon(callback: nil, attributes: nil, tooltip: nil, popover: nil)
            icon(
              :save,
              callback: callback,
              attributes: merge_attributes({ style: { color: 'inherit' } }, attributes),
              tooltip: tooltip,
              popover: popover
            )
          end

          def hamburger_icon(callback: nil, attributes: nil, tooltip: nil, popover: nil)
            icon(
              :menu_hamburger,
              callback: callback,
              attributes: merge_attributes({ style: { color: 'inherit' } }, attributes),
              tooltip: tooltip,
              popover: popover
            )
          end

          # Returns a span element with icon and dropdown menu
          #
          # 1. icon: is the name of the (bootstrap) icon
          # 2. items: should be hashes containing menu items
          #    e.g. { callback: ->{}, href: '#', content: 'list item'}
          # 3. menu_right: set true if right of menu should go under icon
          # 4. icon_attributes: any attributes for icon
          def drop_down_icon(icon: 'menu-hamburger', items: [], menu_right: false, icon_attributes: nil, menu_attributes: nil)
            ddm_params = {
              css: "dropdown-menu #{menu_right && 'dropdown-menu-right'}"
            }
            if menu_attributes
              if (menu_css = menu_attributes.delete(:css) || menu_attributes.delete(:class))
                ddm_params[:css] = ddm_params[:css] + ' ' + menu_css
              end
              ddm_params = merge_attributes(ddm_params, menu_attributes)
            end
            ddm_params[:content] = items.map { |item|
              content = item[:content]
              if content.to_s == 'divider' || content == 'separator'
                div.css(:dropdown_divider)
              else
                if (href = item[:href])
                  dropdown_item_link(content, href, &item[:callback])
                else
                  tag(:button,
                    type: 'button',
                    css: 'dropdown-item',
                    on: { click: item[:callback] || ->{} },
                    content: content
                  )
                end
              end
            }
            div.css(:dropdown)[
              div.data(toggle: 'dropdown')[ # .css('dropdown-toggle')
                icon(icon, attributes: icon_attributes),
              ],
              tag(:div, **ddm_params)
            ]
          end

          def plus_sign_drop_down(items: [], menu_right: false, icon_attributes: nil, menu_attributes: nil)
            _icon_attributes = {
              style: {
                color: 'lightgreen'
              }
            }
            if icon_attributes
              # argument attributes take precedence
              _icon_attributes = merge_attributes(_icon_attributes,  icon_attributes)
            end
            drop_down_icon(
               icon: 'plus-sign',
               items: items,
               menu_right: menu_right,
               icon_attributes: _icon_attributes,
               menu_attributes: menu_attributes
            )
          end

          def plain_link(href: nil, content: nil)
            link(
              href: href,
              style: { color: 'inherit', background_color: 'inherit'},
              content: content
            )
          end

          def div_with_icon(callback: nil, icon: nil, float: nil, content: nil, icon_style: nil, tooltip: nil, popover: nil, image_attributes: nil)
            icon ||= 'question-sign'
            icon_style ||= {}
            image_tag = nil
            if icon == '#image'
              image_tag = self.image_tag(image_attributes)
            end
            float = (float || 'left').to_s
            final_icon_style = {
               font_size: 'smaller',
               # margin_left: '0.5em',
               # margin_right: '0.5em',
               # margin_top: image_tag ? '' : '0.3em',
               # margin_bottom: image_tag ? '0.5em' : '',
               # color: 'inherit',
               # background_color: 'inherit',
            }.merge(
              icon_style # argument style overrides default
            )
            icon_class = "float-#{float} align-middle"
            icon_class = "glyphicon glyphicon-#{icon} " + icon_class unless image_tag
            icon_span = tag(
              :span,
              content: image_tag,
              css: icon_class,
              style: final_icon_style,
              on: { click: callback}
            )
            icon_span.tooltip(tooltip) if tooltip
            icon_span.popover(popover) if popover
            attributes = {
              style: {cursor: 'pointer,'},
              content: arrify(icon_span, content) # image_tag ? arrify(icon_span, content) : arrify(content, icon_span)
            }
            tag(:div, **attributes)
          end

          def div_with_sort_icon(callback: nil, direction: 0, content: nil)
            if direction != 0
              tag(
                :div,
                on: { click: callback },
                style: { cursor: 'pointer' },
                content: arrify(content) + [
                  tag(:span,
                    css: "glyphicon glyphicon-triangle-#{direction > 0 ? 'top' : 'bottom'}",
                    style: {
                       font_size: 'smaller',
                       margin_left: '0.5em',
                       vertical_align: 'middle',
                       color: 'inherit',
                       background_color: 'inherit',
                    }
                  )
                ]
              )
            else
              tag(
                :div,
                on: { click: callback},
                style: { cursor: 'pointer' },
                content: content
              )
            end
          end

          def div_with_menu_up_down(callback: nil, up: true, down: false, content: nil, float: 'left', tooltip: nil, icon_style: nil)
            div_with_up_down_icon(callback: callback, which: :menu, up: up, down: down, content: content, float: float, tooltip: tooltip, icon_style: icon_style)
          end

          def div_with_collapse_up_down(callback: nil, up: true, down: false, content: nil, float: 'left', tooltip: nil, icon_style: nil)
            div_with_up_down_icon(callback: callback, which: :collapse, up: up, down: down, content: content, float: float, tooltip: tooltip, icon_style: icon_style)
          end

          # which can be :collapse or :menu (or string equivalents)
          def div_with_up_down_icon(callback: nil, which: :menu, up: true, down: false, content: nil, float: nil, tooltip: nil, icon_style: nil)
            up = up && !down
            float = float ? float.to_s : 'left'
            left = float == 'left'
            icon_attributes = {
              css: "glyphicon glyphicon-#{which}-#{up ? 'up' : 'down'} float-#{float} align-middle",
              style: {
                color: 'inherit',
                background_color: 'inherit',
                font_size: 'smaller',
                margin_left: left ? '0.3rem' : '0.5rem',
                margin_right: left ? '0.5rem' : '0.3rem',
              }.merge((icon_style || {}).symbolize_keys),
              on: {
                click: callback
              }
            }
            icon = tag(:span, **icon_attributes)
            if tooltip
              if tooltip.is_a?(String)
                tooltip = {
                  animation: true, title: tooltip, placement: 'top', trigger: 'hover focus', delay: { hide: '200' }
                }
              end
              icon.tooltip(tooltip)
            end
            tag(:div, style: { cursor: 'pointer' }, content: arrify(icon, content))
          end

          # Returns a div element with given content and an icon to left or right.
          #
          # 1. icon: is the name of the (bootstrap) icon
          # 2. items: should be hashes containing menu items
          #    e.g. { callback: ->{}, href: '#', content: 'list item'}
          # 3. content: of the div (apart from the icon)
          # 4. float: which side of div to float the icon, 'right' or 'left'
          def div_with_dropdown_icon(icon: 'menu-hamburger', items: [], attributes: nil, content: nil, float: 'right', icon_attributes: nil, menu_attributes: nil)
            content = arrify(
              span.css("float-#{float}").style(margin_left: '0.5rem', margin_right: '0.5rem')[
                drop_down_icon(
                  icon: icon,
                  items: items,
                  menu_right: float.to_s == 'right',
                  icon_attributes: icon_attributes,
                  menu_attributes: menu_attributes
                )
              ],
              content
            )
            params = (attributes || {}).merge(content: content)
            tag(:div, **params)
          end

          # TODO: generalize from bootstrap
          def iconify(icon_name)
            "glyphicon glyphicon-#{icon_name.to_s.kebab_case}"
          end

        end
      end
    end
  end
end

