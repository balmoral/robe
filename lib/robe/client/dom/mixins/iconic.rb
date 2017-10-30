# expects to be include'd in a Robe::Client::Component

require 'robe/common/util'
require 'robe/common/trace'
require 'robe/client/dom/mixins/list_item_link'

module Robe; module Client
  module DOM
    module Iconic
      extend Robe::Util
      include Robe::Util
      include Robe::Client::DOM::ListItemLink
      extend Robe::Client::DOM::ListItemLink

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
        style = { text_align: 'center', color: 'inherit', background_color: 'inherit', cursor: 'pointer' }
        image, css = nil, ''
        if icon_type.to_s == '#image'
          css = attributes.delete(:css) || attributes.delete(:class) || ''
          image = image_tag(attributes)
        else
          css = iconify(icon_type)
          if attributes[:style]
            # arg style overrides any defaults
            style = style.merge(attributes[:style])
          end
          if attributes[:class]
            css = css + ' ' + attributes[:css]
          end
        end
        params = attributes.merge(
          css: css,
          style: style,
          # data: { toggle: 'tooltip' },
          on: (attributes[:on] || {}).merge(callback ? { click: callback } : {}),
          content: image
        )
        # trace __FILE__, __LINE__, self, __method__, " : params = #{params}"
        icon = tag(:span, params)
        if tooltip
          if String === tooltip
            tooltip = {
              animation: true, title: tooltip, placement: 'left', trigger: 'hover focus', delay: { hide: '200' }  }
          end
          # trace __FILE__, __LINE__, self, __method__, " : icon.id = #{icon.id}"
          # tooltip[:container] = icon.id unless tooltip[:container]
          icon.tooltip(tooltip)
        elsif popover
          if String === popover
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
        ul_params = { css: "dropdown-menu#{menu_right ? ' dropdown-menu-right' : ''}" }
        ul_params = merge_attributes(ul_params, menu_attributes) if menu_attributes
        ul_params[:content] = items.map { |item|
          content = item[:content]
          if content.to_s == 'divider' || content == 'separator'
            li.css(:divider)
          else
            list_item_link(content, item[:href], &item[:callback])
          end
        }
        div.css(:dropdown)[
          div.css('dropdown-toggle').data(toggle: 'dropdown') << icon(icon, attributes: icon_attributes),
          tag(:ul, **ul_params)
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

      def div_with_icon(callback: nil, icon: nil, pull: nil, content: nil, icon_style: nil, tooltip: nil, popover: nil, image_attributes: nil)
        icon ||= 'question-sign'
        icon_style ||= {}
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
        icon_span = tag(
          :span,
          content: image_tag,
          css: icon_class,
          style: final_icon_style,
          on: { click: callback}
        )
        if tooltip
          icon_span.tooltip(tooltip)
        elsif popover
          icon_span.popover(popover)
        end
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
          on: { click: callback},
          css: "glyphicon glyphicon-#{which}-#{up ? 'up' : 'down'} pull-#{pull}",
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
        icon = tag(:span, **icon_attributes)
        tag(:div, style: { cursor: 'pointer' }, content: arrify(icon, content))
      end

      # Returns a div element with given content and an icon to left or right.
      #
      # 1. icon: is the name of the (bootstrap) icon
      # 2. items: should be hashes containing menu items
      #    e.g. { callback: ->{}, href: '#', content: 'list item'}
      # 3. content: of the div (apart from the icon)
      # 4. pull: which side of div to pull the icon, 'right' or 'left'
      def div_with_dropdown_icon(icon: 'menu-hamburger', items: [], attributes: nil, content: nil, pull: 'right', menu_attributes: nil)
        content = arrify(
          span(
            drop_down_icon(
              icon: icon,
              items: items,
              menu_right: pull.to_s == 'right',
              menu_attributes: menu_attributes
            )
          )
          .css("pull-#{pull}")
          .style(margin_left: '0.5em', margin_right: '0.5em'),
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
end end

