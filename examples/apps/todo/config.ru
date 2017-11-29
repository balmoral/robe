require 'bundler/setup'
Bundler.require

require './lib/todo-example/server/app'
run ::App.instance