require 'robe/server'

class App < Robe::Server::App
  def self.configure
    config.client_app_path = 'todo-example/client/app.rb'
    config.title = 'RoBE Todo Example'
    config.source_maps = ENV['RACK_ENV'] == 'development'
  end
end