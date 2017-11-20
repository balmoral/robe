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


## Usage

#### config.ru
```
$LOAD_PATH << File.join(Dir.pwd, 'lib')

require 'bundler/setup'
Bundler.require

use Rack::Deflater

require 'your/server/app'

Your::Server::App.configure
Your::Server::App.start

run Your:Server::App
```

#### execution

```
bundle exec puma config.ru
```

License
=======

MIT


