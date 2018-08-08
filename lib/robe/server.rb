require 'opal'
# require 'opal-browser' # sets up paths/gems for Opal builder

# setup Opal load paths for client
%w[lib].each do |dir|
  path = File.expand_path(File.join('..', '..', '..', dir), __FILE__).untaint
  # puts "#{__FILE__}[#{__LINE__}] : Opal.append_path #{path}"
  Opal.append_path path
end

require 'robe/server/rack/sockets/rack_server'
Robe::RackServer.load

module Robe
  # module_function privatises methods
  # when modules/classes include/extend
  extend self

  def server?
    true
  end

  def client?
    false
  end

end

# require server app
require 'robe/server/app'

