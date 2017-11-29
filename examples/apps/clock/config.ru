require 'bundler/setup'
Bundler.require

require './lib/clock-example/server/app'
run ::App.instance
