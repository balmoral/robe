#!/usr/bin/env ruby
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "robe/version"

Gem::Specification.new do |spec|
  spec.name = "robe"
  spec.version = Robe::VERSION
  spec.authors = ["Colin Gunn"]
  spec.email = ["colgunn@icloud.com"]
  spec.summary = %q{Ruby on both ends.}
  spec.description = %q{A complete Ruby framework for server and client.}
  spec.homepage = "https://github.com/balmoral/robe"
  spec.license = "MIT"

  spec.files = Dir[File.join("lib", "**", "*"), File.join("robe", "**", "*")]
  spec.require_paths = ['lib']

  spec.add_dependency 'sprockets-sass', '2.0.0.beta1'
  spec.add_dependency 'json', '~> 2.1'
  spec.add_dependency 'sass', '~> 3.5'
  spec.add_dependency 'uglifier', '~> 3.2'
  spec.add_dependency 'logger', '~> 1.2'
  spec.add_dependency 'mongo', '~> 2.4'
  spec.add_dependency 'bcrypt', '~> 3.1'
  spec.add_dependency 'rack_csrf', '~> 2.6'
  spec.add_dependency 'roda', '~> 3.0'
  spec.add_dependency 'concurrent-ruby', '~> 1.0', '>= 1.0.5' # for tasks
  spec.add_dependency 'faye-websocket', '~> 0.10.4' # for sockets
  spec.add_dependency 'redis', '~> 4.0' # for sockets
end
