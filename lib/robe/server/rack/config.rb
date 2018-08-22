module Robe
  module Server
    module Rack
      module Config
        def config
          @config ||= Robe::Server::Config
        end

        def build?
          @@build = false unless defined?(@@build)
          @@build
        end

        def build=(truthy)
          @@build = truthy
        end

        def production?
          !build? && config.production?
        end

        def development?
          !production?
        end
      end
    end
  end
end
