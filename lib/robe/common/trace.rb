if RUBY_PLATFORM == 'opal'
  # puts "#{__FILE__}[#{__LINE__}] : require 'robe/client/logger'"
  require 'robe/client/util/logger'
else
  # puts "#{__FILE__}[#{__LINE__}] : require 'robe/server/logger'"
  require 'robe/server/util/logger'
end

class Object
  def trace(file, line, object, method, details = nil)
    is_class = object.is_a?(Class) || self.is_a?(Module)
    file = file.sub('/Users/col/dev/workspace/', '')
    msg = "#{file}[#{line}] #{is_class ? object : object.class}#{is_class ? '##' : '#'}#{method ? method : 'proc'}#{details}"
    Robe.logger.debug(msg)
  end
end