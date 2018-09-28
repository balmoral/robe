require 'robe/server'

class App < Robe::Server::App

  task :time, auth: false do
    Time.now.to_s
  end
  
  def self.configure
    config.client_app_rb_path = 'clock-example/client/app.rb'
    config.title = 'RoBE Clock Example'
    # config.source_maps = false
  end
end