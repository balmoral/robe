require 'opal'

# setup Opal load paths for client
%w(lib).each do |dir|
  path = File.expand_path(File.join('..', '..', '..', dir), __FILE__).untaint
  puts "#{__FILE__}[#{__LINE__}] : Opal.append_path #{path}"
  Opal.append_path path
end

# add gems which aren't aware of Opal
# Opal.use_gem 'paggio'

require 'robe/server/rack_server'
Robe::RackServer.load

module Robe
  module_function

  def server?
    true
  end

  def client?
    false
  end

end

# require server app
require 'robe/server/app'

