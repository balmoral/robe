require 'bundler/setup'
Bundler.require
use Rack::Deflater
require 'example/server/app'
::App.configure
::App.start
run ::App