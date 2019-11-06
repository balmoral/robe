#!/usr/bin/env ruby
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "robe/version"

Gem::Specification.new do |s|
  s.name = 'robe'
  s.version = Robe::VERSION
  s.authors = ['Colin Gunn']
  s.email = ['colgunn@icloud.com']
  s.summary = 'Ruby on both ends.'
  s.description = 'Ruby on both ends - a complete Ruby framework for server and client.'
  s.homepage = 'https://github.com/balmoral/robe'
  s.license = 'MIT'
  s.required_ruby_version = '>= 2.6.3'

  s.files = %w'README.md MIT-LICENSE' + Dir[File.join('lib', '**', '*')]
  s.require_paths = ['lib']

  # s.add_dependency 'sprockets-sass' # , '2.0.0.beta1'
  # s.add_dependency 'sass', '~> 3.5'
  s.add_dependency 'json', '~> 2.1'
  s.add_dependency 'uglifier', '~> 4.1'
  s.add_dependency 'logger', '~> 1.4'
  s.add_dependency 'mongo', '~> 2.11'
  s.add_dependency 'bcrypt', '~> 3.1'
  s.add_dependency 'rack-protection', '~> 2.0'
  s.add_dependency 'concurrent-ruby', '~> 1.1'
  s.add_dependency 'faye-websocket', '~> 0.10.4'
  s.add_dependency 'redis', '~> 4.1'
  s.add_dependency 'opal', '~> 1.0' 
  s.add_dependency 'opal-sprockets', '~> 0.4.8.1.0.3.7' 
end
