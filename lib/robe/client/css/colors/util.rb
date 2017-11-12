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