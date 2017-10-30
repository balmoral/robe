module Robe
  class ConfigError < RuntimeError; end
  class DBError < RuntimeError; end
  class ModelError < RuntimeError; end
  class PromiseError < RuntimeError; end
  class UserError < Exception; end
end