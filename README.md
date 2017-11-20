# RoBE

**R**uby **o**n **B**oth **E**nds!

An easily learned full stack application framework for deploying Ruby on both server and client.  

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
- server runs **Roda** for fast routing, CSRF protection 
- simple one-stop server configuration
- a minimum of convention to master 
- no mandated JavaScript libraries (except jquery), but...
- inline JavaScript and access to any JavaScript library via **Opal** 
- **source maps** to easily debug Ruby code on the client
- small footprint on server and client
- an aversion to opaque magic
- an embrace of **productive happiness** 
  
So why leave Ruby behind when coding for the client? 

## Acknowledgements

RoBE has been inspired by the great work of some very dedicated, enthusiastic and talented
people who have already developed great frameworks and toolkits for putting Ruby on the client. 

We would particularly like to acknowledge these sources of inspiration and learning:

- the trailblazing now sadly inactive [*Volt*](https://github.com/voltrb/volt) - thanks to Ryan Stout
- the pure and powerful [*Clearwater*](https://github.com/clearwater-rb) - thanks to Jamie Gaskins
- the amazing tierless and tireless [*Ruby-Hyperloop*](http://ruby-hyperloop.org) - thanks to Mitch VanDuyn and the team
- the essential and extraorindary [*Opal*](http://opalrb.com/) - thanks to all at team Opal  
  
We've borrowed ideas and patterns and implementations from you all, 
to have some fun experimenting and to learn by doing.
 
We hope there's something useful here for others, 
acknowledging that it's early days for us with much more yet to learn and implement.
(We're still not sure we know what we're doing.)   

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

Copyright (c) 2017 Colin Gunn

MIT License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
