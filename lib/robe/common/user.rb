require 'robe/common/model'

module Robe
  class User < Robe::Model
    attr :id, :name, :token
  end
end