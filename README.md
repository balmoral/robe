# Robe

The best of both worlds with **R**uby **o**n **b**oth **e**nds.

Robe is a Ruby application framework for developing and deploying Ruby apps on both server and client.  

### Robe

1. provides a readable, concise, adaptable, object-oriented DOM interface   
1. provides simple and powerful **state** management
1. facilitates **binding** the DOM to **state** clearly and simply 
1. has built-in **Mongo** support on both ends 
1. allows **tasks** to be defined on the server, requested from the client
1. has simple configuration
1. has little convention to master 
1. has a small footprint compared to **Rails, Hyperloop, React,** ...
1. requires no javascript libraries other than **jquery**, but...
1. allows use of any javascript library via **Opal** 
1. has a minimum of opaque magic
1. delivers a maximum of productive happiness 

### Robe is:

1. a work in progress serving existing bespoke commercial applications
1. undergoing constant change as we play, learn and require more  
  
## Installation

Add this line to your application's Gemfile:

    gem 'robe'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install robe



## config.ru
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

## Usage
```
bundle exec puma config.ru
```
    
more comming soon...

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
