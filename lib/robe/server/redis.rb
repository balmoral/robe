require 'redis'

module Robe
  module_function

  def redis
    @redis ||= ::Redis.new
  end

end
