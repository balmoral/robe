require 'redis'

module Robe
  def self.redis
    @redis ||= ::Redis.new
  end
end