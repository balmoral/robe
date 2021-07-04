require 'redis'

module Robe
  module_function

  def redis
    if Robe.config.use_redis?
      @redis ||= ::Redis.new
    else
      nil
    end  
  end

end
