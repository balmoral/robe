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
        p[
          "The time is now #{@clock.time}"
        ]
      }
    end
  end

  def render
    div[
      h1.style(color: :darkgray)[
        'RoBE Example'
      ],
      p.style(font_weight: :bold)[
        'Hello world!'
      ],
      ClockComponent.new
    ]
  end
end