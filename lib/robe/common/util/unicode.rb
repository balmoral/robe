
module Robe
  module Unicode
    module_function

    def unicode(symbol)
      # TODO: http://ascii-table.com/ansi-codes.php
      case symbol
        when :middle_dot;       "\u00B7"
        when :bullet;           "\u2022"
        when :ellipsis;         "\u2026"
        when :euro;             "\u20AC"
        when :dagger;           "\u2020"
        when :double_dagger;    "\u2021"
        when :em_dash;          "\u2014" # longer dash
        when :tm;               "\u2122"
        when :pound;            "\u00A3"
        when :yen;              "\u00A5"
        when :copyright;        "\u00A9"
        when :registered;       "\u00AE"
        when :check_mark;       "\u2713" # light tick
        when :heavy_check_mark; "\u2714" # heavy tick
        else symbol.to_s
      end
    end

end end
