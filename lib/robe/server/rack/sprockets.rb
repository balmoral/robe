require 'sprockets'

module Robe
  module Server
    module Rack
      class Sprockets
      end
    end
  end
end

require 'robe/server/rack/opal'
require 'robe/server/rack/paths'

# ref :http://recipes.sinatrarb.com/p/asset_management/sprockets
module Robe
  module Server
    module Rack
      class Sprockets
        extend Robe::Server::Rack::Paths

        def self.handle
          @handle ||= lambda do |arg|
            path_info = arg['PATH_INFO']
            if path_info.end_with?('jpg')
              trace __FILE__, __LINE__, self, __method__, " PATH_INFO=#{path_info}"
            end
            sync do
              self.env.call(arg)
            end
          end
        end

        # ref: https://github.com/rails/sprockets/blob/master/guides/how_sprockets_works.md
        def self.env
          unless @env
            @env = ::Sprockets::Environment.new
            @env.logger.level = config.sprockets_logger_level
            if config.sprockets_memory_cache_size
              @env.cache = ::Sprockets::Cache::MemoryStore.new(config.sprockets_memory_cache_size)
            end
            if production?
              @env.append_path(File.join(public_path, public_assets_path))
            else
              trace __FILE__, __LINE__, self, __method__, " build? = #{build?}"
              @env.append_path('') if build?
              @env.append_path(assets_path)
            end
            trace __FILE__, __LINE__, self, __method__, " : @env.paths=#{@env.paths}"
          end
          @env
        end

        # To avoid concurrency problem in sprockets which results in
        # `RuntimeError: can't add a new key into hash during iteration.`
        # we sync all calls to sprockets - only in development?
        def self.sync(&block)
          if production?
            block.call #(self.env)
          else
            (@sprockets_mutex ||= Mutex.new).synchronize(&block)
          end
        end
      end
    end
  end
end

