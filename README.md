# Robe

Ruby on 'both ends'! 

Robe is a Ruby application framework which runs on both server and client.  

### Robe provides:

1. easy DOM management via client side Ruby
1. adaptable components such as tables and forms 
1. access to opal-browser DOM functionality without need for paggio dsl
1. the basis for DOM functionality within the Volt framework 

### Robe is:

1. a work in progress serving existing bespoke commercial applications
1. undergoing constant change as we learn and require more  
  
## Installation

Add this line to your application's Gemfile:

    gem 'robe'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install robe


## Usage

## config.ru
\ -s puma
require 'bundler/setup'
Bundler.require
use Rack::Deflater
require_relative './lib/server/app'
run App

Contributing
============

1. Fork it ( http://github.com/[my-github-username]/dom-rb/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

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
