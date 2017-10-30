module Robe; module CSS
  module Bootstrap3
    module Colors
      # from BOOTSTRAP 3

      # GRAYS

      GRAY_BASE     = '#000'
      GRAY_DARKER   = '#222'
      GRAY_DARK     = '#333'
      GRAY          = '#555'
      GRAY_LIGHT    = '#777'
      GRAY_LIGHTER  = '#eee'

      # BRAND COLORS

      COLOR_BRAND_PRIMARY     = '#337ab7'
      COLOR_BRAND_SUCCESS     = '#cb85c'
      COLOR_BRAND_INFO        = '#bc0de'
      COLOR_BRAND_WARNING     = '#f0ad4e'
      COLOR_BRAND_DANGER      = '#d9534f'

      # BUTTON COLORS

      COLOR_BUTTON_PRIMARY    = '#337ab7'
      COLOR_BUTTON_SUCCESS    = '#449d44'
      COLOR_BUTTON_INFO       = '#31b0d5'
      COLOR_BUTTON_WARNING    = '#ec971f'
      COLOR_BUTTON_DANGER     = '#c9302c'

      # STATE & ALERT COLORS

      COLOR_STATE_SUCCESS     = '#3c763d'
      COLOR_STATE_SUCCESS_BG  = '#dff0d8'

      COLOR_STATE_INFO        = '#31708f'
      COLOR_STATE_INFO_BG     = '#d9edf7'

      COLOR_STATE_WARNING     = '#8a6d3b'
      COLOR_STATE_WARNING_BG  = '#fcf8e3'

      COLOR_STATE_DANGER      = '#a94442'
      COLOR_STATE_DANGER_BG   = '#f2dede'

    end
  end
end end

class String

  #  Amount should be a decimal between 0 and 1. Higher means darker.
  def rgb_darker(amount = 0.5)
    amount = 1.0 - amount
    amount = 1.0 if amount > 1.0
    amount = 0.0 if amount < 0.0
    hex_color = gsub('#','')
    rgb = hex_color.scan(/../).map {|color| color.hex}
    rgb[0] = [(rgb[0].to_i * amount).round, 255].min
    rgb[1] = [(rgb[1].to_i * amount).round, 255].min
    rgb[2] = [(rgb[2].to_i * amount).round, 255].min
    '#%02x%02x%02x' % rgb
  end
  alias_method :rgb_darken, :rgb_darker

  # Amount should be a decimal between 0 and 1. Higher means lighter.
  def rgb_lighter(amount=0.6)
    amount = 1.0 if amount > 1.0
    amount = 0.0 if amount < 0.0
    hex_color = gsub('#','')
    rgb = hex_color.scan(/../).map {|color| color.hex}
    rgb[0] = [(rgb[0].to_i + 255 * amount).round, 255].min
    rgb[1] = [(rgb[1].to_i + 255 * amount).round, 255].min
    rgb[2] = [(rgb[2].to_i + 255 * amount).round, 255].min
    '#%02x%02x%02x' % rgb
  end
  alias_method :rgb_lighten, :rgb_lighter

end