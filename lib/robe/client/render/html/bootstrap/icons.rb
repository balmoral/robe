module Robe; module DOM; module Render; module HTML
  module Bootstrap
    module_function

    # e.g. attributes = {
    #   src: nil,
    #   width: '16px',
    #   height: '16px',
    # }
    # https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img
    def image_tag(attributes)
      attributes[:width] ||= '16px'
      attributes[:height] ||= '16px'
      tag(
        :img,
        attributes: attributes
      )
    end

    # if attributes contain image attributes set icon to '#image'
    def icon(icon_type, attributes: nil, callback: nil, tooltip: nil, popover: nil)
      style = {
        text_align: 'center',
        color: 'inherit',
        background_color: 'inherit',
        cursor: 'pointer',
      }
      image, klass = nil, ''
      if icon_type.to_s == '#image'
        klass = attributes.delete(:class) || ''
        image = image_tag(attributes)
      else
        klass = iconify(icon_type)
        if attributes
          if attributes[:style]
            # arg style overrides any defaults
            style = style.merge(attributes[:style])
          end
          if attributes[:class]
            klass = klass + ' ' + attributes[:class]
          end
        end
      end
      attributes = {
        class: klass,
        style: style
      }.merge(
        callback ? { onclick: callback } : {}
      )
      icon = tag(
        :span,
        content: [image].compact,
        attributes: attributes
      )
      if tooltip
        icon.tooltip(tooltip)
      elsif popover
        icon.popover(popover)
      end
      icon
    end

    def icon_with_anchor(icon_name, href, icon_attributes: nil, anchor_attributes: nil, tooltip: nil, popover: nil)
      attributes = { href: href }
      if anchor_attributes
        attributes = merge_attributes(anchor_attributes, attributes)
      end
      tag(
        :a,
        attributes: attributes,
        content: icon(icon_name, attributes: icon_attributes, tooltip: tooltip, popover: popover)
      )
    end

    def plus_sign_icon_anchor(href, icon_attributes: nil, anchor_attributes: nil, tooltip: nil, popover: nil)
      _icon_attributes = {
        style: {
          color: 'lightgreen',
        }
      }
      if icon_attributes
        # argument takes precedence
        _icon_attributes = merge_attributes(_icon_attributes, icon_attributes)
      end
      icon_with_anchor(
        :plus_sign,
        href,
        icon_attributes: _icon_attributes,
        anchor_attributes: anchor_attributes,
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
      icon(
        :remove_sign,
        callback: callback,
        attributes: merge_attributes({ style: {color: 'red'} }, attributes),
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
        :step_backward,
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
      _menu_attributes = {
          class: "dropdown-menu#{menu_right ? ' dropdown-menu-right' : nil}"
      }
      if menu_attributes
        _menu_attributes  = merge_attributes(_menu_attributes, menu_attributes)
      end
      div(
        attributes: {
          class: 'dropdown',
        },
        content: [
          div(
            attributes: {
              class: 'dropdown-toggle',
              data_toggle: 'dropdown',
            },
            content: icon(
              icon,
              attributes: icon_attributes
            )
          ),
          tag(
            :ul,
            attributes: _menu_attributes,
            content: items.map { |item|
              content = item[:content]
              if content == 'divider' || content == 'separator'
                tag(
                  :li,
                  attributes: {
                    role: 'separator',
                    class: 'divider',
                  }
                )
              else
                attrs = {}
                attrs[:href] = item[:href] if item[:href]
                attrs[:onclick] = item[:callback] if item[:callback]
                tag(
                  :li,
                  content: tag(
                    :div,
                    content: content,
                    attributes: attrs
                  )
                )
              end
            }
          )
        ]
      )
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

    def plain_anchor(content, href)
      tag(
        :a,
        attributes: {
          href: href,
          style: { color: 'inherit', background_color: 'inherit'}
        },
        content: content
      )
    end

    def div_with_icon(callback: nil, icon: nil, pull: nil, attributes: nil, content: nil, icon_style: {}, tooltip: nil, popover: nil, image_attributes: nil)
      icon ||= 'question-sign'
      image_tag = nil
      if icon == '#image'
        image_tag = self.image_tag(image_attributes)
      end
      pull ||= 'left'
      pull = pull.to_s
      final_icon_style = {
         font_size: 'smaller',
         margin_left: '0.5em',
         margin_right: '0.5em',
         margin_top: image_tag ? '' : '0.3em',
         margin_bottom: image_tag ? '0.5em' : '',
         color: 'inherit',
         background_color: 'inherit',
      }.merge(
        icon_style # argument style overrides default
      )
      icon_class = "pull-#{pull}"
      icon_class = "glyphicon glyphicon-#{icon} " + icon_class unless image_tag
      # debug 0, ->{[__FILE__, __LINE__, __method__, "image_tag=#{image_tag} icon_class=#{icon_class}"]}
      icon_span = span(
        content: image_tag,
        attributes: {
          onclick: callback,
          class: icon_class,
          style: final_icon_style
        }
      )
      debug 1, ->{[__FILE__, __LINE__, __method__, "tooltip=#{tooltip} popover=#{popover}"]}
      if tooltip
        icon_span.tooltip(tooltip)
      elsif popover
        icon_span.popover(popover)
      end
      tag(
        :div,
        attributes: merge_attributes(
          { style: { cursor: 'pointer' } },
          attributes
        ),
        content: arrify(icon_span, content) # image_tag ? arrify(icon_span, content) : arrify(content, icon_span)
      )
    end

    def div_with_sort_icon(callback: nil, direction: 0, content: nil)
      if direction != 0
        tag(
          :div,
          attributes: {
            onclick: callback,
            style: { cursor: 'pointer' }
          },
          content: arrify(content) + [
            tag(:span,
              attributes: {
                class: "glyphicon glyphicon-triangle-#{direction > 0 ? 'top' : 'bottom'}",
                style: {
                   font_size: 'smaller',
                   margin_left: '0.5em',
                   vertical_align: 'middle',
                   color: 'inherit',
                   background_color: 'inherit',
                }
              }
            )
          ]
        )
      else
        tag(
          :div,
          attributes: {
            onclick: callback,
            style: { cursor: 'pointer' }
          },
          content: content
        )
      end
    end

    def div_with_menu_up_down(callback: nil, up: true, down: false, content: nil, pull: 'left')
      div_with_up_down_icon(callback: callback, which: :menu, up: up, down: down, content: content, pull: pull)
    end

    def div_with_collapse_up_down(callback: nil, up: true, down: false, content: nil, pull: 'left')
      div_with_up_down_icon(callback: callback, which: :collapse, up: up, down: down, content: content, pull: pull)
    end

    # which can be :collapse or :menu (or string equivalents)
    def div_with_up_down_icon(callback: nil, which: :menu, up: true, down: false, content: nil, pull: 'left')
      up = up && !down
      pull = pull.to_s
      left = pull == 'left'
      icon_attributes = {
        onclick: callback,
        class: "glyphicon glyphicon-#{which}-#{up ? 'up' : 'down'} pull-#{pull}",
        style: {
          font_size: 'smaller',
          margin_top: '0.2em',
          margin_left: left ? '0.3em' : '0.5em',
          margin_right: left ? '0.5em' : '0.3em',
          vertical_align: 'middle',
          color: 'inherit',
          background_color: 'inherit',
        }
      }
      icon = tag(
        :span,
        attributes: icon_attributes
      )
      div(
        attributes: {
          # onclick: callback,
          style: { cursor: 'pointer' }
        },
        content: arrify(icon, content)
      )
    end

    # Returns a div element with given content and an icon to left or right.
    #
    # 1. icon: is the name of the (bootstrap) icon
    # 2. items: should be hashes containing menu items
    #    e.g. { callback: ->{}, href: '#', content: 'list item'}
    # 3. content: of the div (apart from the icon)
    # 4. pull: which side of div to pull the icon, 'right' or 'left'
    def div_with_dropdown_icon(icon: 'menu-hamburger', items: [], attributes: nil, content: nil, pull: 'right', menu_attributes: nil)
      tag(
        :div,
        attributes: attributes,
        content: arrify(
          tag(
            :span,
            attributes: {
              class: "pull-#{pull}",
              style: {
                margin_left: '0.5em',
                margin_right: '0.5em'
              }
            },
            content: drop_down_icon(
              icon: icon,
              items: items,
              menu_right: pull.to_s == 'right',
              menu_attributes: menu_attributes
            )
          ),
          content
        )
      )
    end

    # TODO: generalize from bootstrap
    def iconify(icon_name)
      "glyphicon glyphicon-#{icon_name.to_s.gsub('_', '-')}"
    end

  end

end end end end

