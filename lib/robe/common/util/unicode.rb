
module Robe
  module Unicode
    module_function

    SYMBOLS = {
      no_break_space:   "\u00A0",
      middle_dot:       "\u00B7",
      bullet:           "\u2022",
      ellipsis:         "\u2026",
      euro:             "\u20AC",
      dagger:           "\u2020",
      double_dagger:    "\u2021",
      em_dash:          "\u2014", # longer dash
      tm:               "\u2122",
      pound:            "\u00A3",
      yen:              "\u00A5",
      copyright:        "\u00A9",
      registered:       "\u00AE",
      check_box:        "\u2610", # ballot box - empty square
      checked_box:      "\u2612", # square with x
      ballot_x:         "\u2717", # freehand style x
      ballot_x_heavy:   "\u2718", # heavy freehand style x
      check_mark:       "\u2713", # light tick
      heavy_check_mark: "\u2714", # heavy tick
      multiplication_x: "\u2715",
      saltire:          "\u2613", # St Andrew's Cross - good for close x
    }

    def unicode(symbol)
      # TODO: http://ascii-table.com/ansi-codes.php
      SYMBOLS[symbol.to_sym] || symbol
    end

end end
