module Robe

  class Error < ::Exception
    def initialize(msg)
      Robe.logger.error("#{self.class.name} => #{msg}") if Robe.logger
      super
    end
  end

  class RuntimeError  < Robe::Error; end
  class ConfigError   < Robe::Error; end
  class DBError       < Robe::Error; end
  class ModelError    < Robe::Error; end
  class PromiseError  < Robe::Error; end
  class UserError     < Robe::Error; end
  class TaskError     < Robe::Error; end
  class TimeoutError  < Robe::Error; end
end