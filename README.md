# ROBE

#### Ruby on both ends.

**Robe** is a full stack, single page application framework for server and client:  

- share Ruby code on server and client
- almost no HTML - do it all in Ruby
- a readable, concise, adaptable, re-usable, object-oriented **DOM** interface
- simple yet powerful **state** management
- fine-grained **bindings** between state and DOM   
- easy to define server **api** and **tasks** 
- built-in **Mongo** support (Sequel/AR to come)
- database models with validation and associations 
- write-through database caching on the client 
- **websockets** and **Redis** built-in  
- simple one-stop server configuration
- no mandated JavaScript libraries (except jquery), but...
- inline JavaScript and access to any JavaScript library via **Opal** 
- **source maps** to view and debug Ruby on the client
- small footprint
- fast to learn
- fun to play with
- surprisingly powerful
- easy to deploy
 
## Acknowledgements

**Robe** has been inspired by a few great client-side Ruby libraries and frameworks. 

Special appreciation and acknowledgement goes to:

- the trailblazing (now inactive) [*Volt*](https://github.com/voltrb/volt) 
- the virtual [*Clearwater*](https://github.com/clearwater-rb)
- the reactive [*Ruby-Hyperloop*](http://ruby-hyperloop.org)
- the enabling [*Opal*](http://opalrb.com/) 

## Installation

Add this line to your application's Gemfile:

    gem 'robe'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install robe


## Example

This mini-app demonstrates Robe's

- concise DOM DSL
- reusable DOM components
- atomic state management
- explicit bindings between state and DOM
- performing server-side tasks 
- minimum of server configuration

in under 100 lines of easy-to-read Ruby.

#### on the client

```ruby
require 'robe/client/app'
require 'robe/common/state/atom'

class App < Robe::Client::App

  class Clock < Robe::State::Atom
    attr :client_time
    attr :server_time
  end

  class TimeDiv < Robe::Client::Component
    def initialize(which, clock)
      @name = which.to_s.upcase
      @method = :"#{which}_time"
      @clock = clock
    end

    def render
      P.style(color: :white, background_color: :darkgray, width: 27.em, padding: 0.5.em)[
        SPAN[
          @name
        ],
        SPAN.style(float: :right)[
          @clock.send(@method)
        ]
      ]
    end
  end

  class ClockDiv < Robe::Client::Component
    def initialize(clock)
      @clock = clock
    end

    def render
      # update DOM when clock state changes
      bind(@clock) {
        DIV[
          TimeDiv.new(:server, @clock),
          TimeDiv.new(:client, @clock),
        ]
      }
    end
  end

  class Page < Robe::Client::Component
    def initialize
      @clock = Clock.new
      every(1000) do
        # get the time on the server using a task
        app.perform_task(:time).then do |server_time|
          @clock.mutate!(
            server_time: server_time,
            client_time: Time.now.to_s
          )
        end
      end
    end

    def render
      DIV.style(font_family: 'Helvetica')[
        H1[
          'Robe => Ruby on Both Ends.'
        ],
        H5.style(color: :orangered)[
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

::App.new.mount

```

#### on the server

```ruby
require 'robe/server'

class App < Robe::Server::App

  task :time do
    Time.now.to_s
  end
  
  def self.configure
    config.client_app_path = 'client/app.rb'
    config.title = 'Robe Clock Example'
  end
end
```

#### Gemfile

```ruby
source 'https://rubygems.org'
# go to git masters until published gems catch up
gem 'robe', :git => 'https://github.com/balmoral/robe'
gem 'opal', :git => 'https://github.com/opal/opal' # 0.11.0.rc1
gem 'opal-sprockets', :git => 'https://github.com/opal/opal-sprockets' # for opal 0.11.0.rc1
gem 'opal-browser', :git => 'https://github.com/opal/opal-browser' # 0.2.0 
# choose your server
gem 'puma' # or thin

```

#### config.ru

```ruby
require 'bundler/setup'
Bundler.require

require './example/server/app'
run ::App.instance
```

#### server execution

```sh
bundle exec puma config.ru
```

or

```sh
bundle exec thin start --rackup config.ru -p 9292
```

Your Gemfile should specify `puma` or `thin` accordingly.

## License

MIT


