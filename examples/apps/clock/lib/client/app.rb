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
          @clock.time.to_s
        ]
      }
    end

    def color
      %i(magenta blue)[@clock.time.to_i % 2]
    end
  end

  class Page < Robe::Client::Component
    def render
      div.style(font_family: 'Helvetica', text_align: :center)[
        h1[
          'RoBE'
        ],
        h2.style(color: :darkred)[
          'Ruby on Both Ends'
        ],
        h3.style(color: :orange)[
          'The time has come for Ruby on the client!'
        ],
        hr,
        ClockComponent.new
      ]
    end
  end

  def initialize
    super Page.new
  end

end

::App.new.mount
