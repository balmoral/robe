require 'robe/server'

class App < Robe::Server::App
  def self.configure
    config.client_app_path = 'client/app.rb'
    config.title = 'RoBE Clock Example'
    config.source_maps = ENV['RACK_ENV'] == 'development'

    config.html_literal_head = <<-HTML
      <meta charset="utf-8">
      <meta content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0' name='viewport' />
      <meta http-equiv="x-ua-compatible" content="ie=edge"/>  
      <script src="https://code.jquery.com/jquery-3.2.1.min.js" integrity="sha256-hwg4gsxgFZhOsEEamdOYGBf13FyQuiTwlAQgxVSNgt4=" crossorigin="anonymous"></script>
    HTML
  end
end