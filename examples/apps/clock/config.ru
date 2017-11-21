require 'bundler/setup'
Bundler.require
use Rack::Deflater
require './lib/server/app'
::App.configure
::App.start
run ::App