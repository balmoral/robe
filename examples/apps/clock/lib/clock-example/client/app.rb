require 'robe/client/app'
require 'robe/client/browser/dom/component'
require 'robe/common/state/atom'

class App < Robe::Client::App

  class Clock < Robe::State::Atom
    attr :client_time
    attr :server_time
  end

  class TimeDiv < Robe::Client::Browser::DOM::Component
    def initialize(which, clock)
      @name = which.to_s.upcase
      @method = :"#{which}_time"
      @clock = clock
    end

    def render
      p.style(color: :white, background_color: :darkgray, width: 27.em, padding: 0.5.em)[
        span[@name],
        bind(@clock, @method) {
          span.style(float: :right)[
            @clock.send(@method)
          ]
        }
      ]
    end
  end

  class ClockDiv < Robe::Client::Browser::DOM::Component
    def initialize(clock)
      @clock = clock
    end

    def render
      # update DOM when clock state changes
      div[
        TimeDiv.new(:server, @clock),
        TimeDiv.new(:client, @clock),
      ]
    end
  end

  class Page < Robe::Client::Browser::DOM::Component
    def initialize
      @clock = Clock.new
      every(1000) do
        # get the time on the server using a task
        app.perform_task(:time).then do |server_time|
          @clock.mutate!(server_time: server_time)
          @clock.mutate!(client_time: Time.now.to_s)
        end
      end
    end

    def render
      div.style(font_family: 'Helvetica')[
        h1[
          'RoBE => Ruby on Both Ends.'
        ],
        h5.style(color: :orangered)[
          'the time has come for Ruby on the server and the client...'.upcase
        ],
        ClockDiv.new(@clock)
      ]
    end
  end

  def initialize
    super Page.new
  end

end

# Robe.app is set by Robe::Client::App
$app = ::App.new
$app.mount
