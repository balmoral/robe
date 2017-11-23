require 'bundler/setup'
Bundler.require
use Rack::Deflater
require './lib/todo-example/server/app'
run ::App.start