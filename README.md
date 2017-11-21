# RoBE

**R**uby **o**n **B**oth **E**nds!

An easily learned, easily deployed full stack Ruby application framework for server and client.  

Highlights are:

- a readable, concise, adaptable, re-usable, object-oriented DOM interface
- almost **no HTML** - do it all in Ruby
- bring-your-own CSS and JavaScript as required  
- simple yet powerful **state** management
- simple explicit fine-grained **binding** of DOM to state  
- **tasks** defined and performed on the server, requests made from the client
- built-in **Mongo** support - Sequel/ROM/AR to come
- models come with built-in validation and associations 
- easy write-through database caching on the client 
- integrated **websocket** support plus **Redis** pub/sub  
- runs **Roda** on the server for fast routing, CSRF protection 
- simple one-stop server configuration
- a minimum of convention to master 
- no mandated JavaScript libraries (except jquery), but...
- inline JavaScript and access to any JavaScript library via **Opal** 
- **source maps** to easily debug Ruby code on the client
- small footprint on server and client
- an aversion to opaque magic
- an embrace of **productive happiness**  

## Acknowledgements

RoBE has been inspired by the great work of some very dedicated, enthusiastic and talented
people who have provided client-side Ruby libraries and frameworks. 

Special appreciation and acknowledgement goes to these sources of inspiration and learning:

- the trailblazing now sadly inactive [*Volt*](https://github.com/voltrb/volt) - thanks Ryan Stout
- the pure and powerful [*Clearwater*](https://github.com/clearwater-rb) - thanks Jamie Gaskins
- the remarkable and reactive [*Ruby-Hyperloop*](http://ruby-hyperloop.org) - thanks Mitch VanDuyn and the team
- the essential and enabling [*Opal*](http://opalrb.com/) - thanks to Adam Beynon, Elia Schito and the team  

## Installation

Add this line to your application's Gemfile:

    gem 'robe'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install robe


## Example

#### on the client

```ruby
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

```

#### on the server

```ruby
require 'robe/server'

class App < Robe::Server::App
  def self.configure
    config.client_app_path = 'example/client/app.rb'
    config.title = 'RoBE Example'
    config.source_maps = ENV['RACK_ENV'] == 'development'
    # make sure you bring jquery
    config.html_literal_head = <<-HTML
      <meta charset="utf-8">
      <meta content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0' name='viewport' />
      <meta http-equiv="x-ua-compatible" content="ie=edge"/>  
      <script src="https://code.jquery.com/jquery-3.2.1.min.js" integrity="sha256-hwg4gsxgFZhOsEEamdOYGBf13FyQuiTwlAQgxVSNgt4=" crossorigin="anonymous"></script>
    HTML
  end
end
```

#### Gemfile

```ruby
source 'https://rubygems.org'
# go to git masters until published gems catch up
gem 'robe', :git => 'https://github.com/balmoral/robe'
gem 'opal', :git => 'https://github.com/opal/opal' # 0.11.0.dev
gem 'opal-sprockets', :git => 'https://github.com/opal/opal-sprockets' # 0.11.0.dev
gem 'opal-browser', :git => 'https://github.com/opal/opal-browser'
# choose your server
gem 'puma' # or thin

```

#### config.ru

```ruby
require 'bundler/setup'
Bundler.require
use Rack::Deflater
require 'example/server/app'
run ::App.start
```

#### server execution

```ruby
bundle exec puma config.ru
```

## License

MIT


