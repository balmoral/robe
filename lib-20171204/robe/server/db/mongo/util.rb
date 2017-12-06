
module Robe; module DB
  module Mongo
    module Util
      module_function

      # WARNING - this sets logger level for all clients
      # level can be :debug, :fatal
      def logger_level=(level)
        ::Mongo::Logger.logger.level = case level
          when :debug
            ::Logger::DEBUG
          when :fatal
            ::Logger::FATAL
          else
            nil
        end
      end

      def new_object_id
        BSON::ObjectId.new.to_s
      end

    end
  end
end end

class Hash
  def symbolize_keys
    result = {}
    each { |k, v| result[k.to_sym] = v}
    result
  end
end