require 'bundler/setup'
Bundler.require
use Rack::Deflater
require './lib/server/app'
run ::App.start