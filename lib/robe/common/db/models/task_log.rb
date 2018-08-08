require 'robe/common/db/model'

module Robe
  module DB
    module Models
      class TaskLog < Robe::DB::Model
        attr  :time, type: String
        attr  :task, type: String
        attr  :args, type: String
      end
    end
  end
end
