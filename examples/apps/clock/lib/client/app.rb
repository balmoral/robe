require 'robe/client/app'
require 'robe/common/state/atom'

class App < Robe::Client::App

  class Clock < Robe::State::Atom
    attr :time

    def initialize
      super
      tick!
    end

    def tick!
      mutate!(time: Time.now)
    end
  end

  class ClockComponent < Robe::Client::Component
    def initialize
      @clock = Clock.new
      every(1000) { @clock.tick! }
    end

    def render
      bind(@clock) {
        p.style(color: color)[
          @clock.time.strftime('%I:%M:%S %p')
        ]
      }
    end

    def color
      %i(green pink orange cyan orange)[@clock.time.to_i % 5]
    end
  end

  class Page < Robe::Client::Component
    def render
      div.style(text_align: :center)[
        h1[
          'RoBE Example'
        ],
        p.style(font_weight: :bold, font_size: :larger, color: :blue)[
          'The time has come for Ruby on the client!'
        ],
        ClockComponent.new
      ]
    end
  end

  def initialize
    super Page.new
  end

end

::App.new.mount
