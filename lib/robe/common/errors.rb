module Robe

  class Exception < ::RuntimeError
    def initialize(msg)
      super
      Robe.logger.error("#{self.class.name} => #{msg}")
    end
  end

  class ConfigError   < Robe::Exception; end
  class DBError       < Robe::Exception; end
  class ModelError    < Robe::Exception; end
  class PromiseError  < Robe::Exception; end
  class UserError     < Robe::Exception; end
end