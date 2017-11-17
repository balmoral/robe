# Robe

The best of both worlds with **R**uby **o**n **b**oth **e**nds.

Robe
- is a Ruby application framework for developing and deploying Ruby apps on both server and client.  
- provides a readable, concise, adaptable, object-oriented DOM interface   
- provides simple and powerful **state** management
- facilitates **binding** the DOM to **state** clearly and simply 
- has built-in **Mongo** support on both ends 
- allows **tasks** to be defined on the server, requested from the client
- has simple configuration
- has little convention to master 
- has a small footprint compared to **Rails, Hyperloop, React,** ...
- requires no javascript libraries other than **jquery**, but...
- allows use of any javascript library via **Opal** 
- has a minimum of opaque magic
- delivers a maximum of productive happiness 
  
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
