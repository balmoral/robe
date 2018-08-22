require 'yaml'
require 'opal'
require 'opal-sprockets' # for Opal >= 0.11, included in Opal 0.10
require 'uglifier'
require 'robe/server/rack/paths'

module Opal::Sprockets::Processor
  module PlainJavaScriptLoader
    def self.call(input)
      # trace __FILE__, __LINE__, self, __method__, " : input[:filename]=#{input[:filename]}"

      sprockets = input[:environment]
      asset = OpenStruct.new(input)

      opal_extnames = sprockets.engines.map do |ext, engine|
        ext if engine <= ::Opal::Processor
      end.compact

      path_extnames     = -> path  { File.basename(path).scan(/\.[^.]+/) }
      processed_by_opal = -> asset { (path_extnames[asset.filename] & opal_extnames).any? }

      unless processed_by_opal[asset]
        # trace __FILE__, __LINE__, self, __method__, " : input[:name]=#{input[:name]}"
        [
          input[:data],
          %{if (typeof(OpalLoaded) === 'undefined') OpalLoaded = []; OpalLoaded.push(#{input[:name].to_json});}
        ].join(";\n")
      end
    end
  end
end

module Robe
  module Server
    module Rack
      class Opal
        extend Robe::Server::Rack::Paths
        
        MIN_OPAL_VERSION = '0.10.5' # 0.11'

        def self.load_asset(path)
          sprockets # ensure opal and sprockets paths are set
          ::Opal::Sprockets.load_asset(path)
        end
        # Returns Robe::Server::Rack::Sprockets.
        # On first call configures Robe::Server::Rack::Sprockets.env for Opal.
        def self.sprockets
          unless @sprockets
            @sprockets = Robe::Server::Rack::Sprockets
            check_version
            register_opal_unaware_gems # do first so Opal::paths set
            ::Opal.paths.each do |path|
              @sprockets.env.append_path(path)
            end
            @sprockets.env.append_path(config.rb_path)
          end
          @sprockets
        end
        
        def self.compile_with_builder(path)
          path = path.sub('.js', '')
          # trace __FILE__, __LINE__, self, __method__, " : path=#{path}"
          ::Opal.append_path('lib')  # TODO: move this to call once!
          ::Opal::Builder.build(path).to_s
        end

        def self.check_version
          if ::Opal::VERSION < MIN_OPAL_VERSION
            raise "Opal version must be >= #{MIN_OPAL_VERSION}"
          end
        end

        # Gems which are Opal aware set load paths within Opal.
        def self.register_opal_unaware_gems
          check_version
          config.opal_unaware_gems.each do |gem|
            # trace __FILE__, __LINE__, self, __method__, " : calling Opal.use_gem(#{gem}, true)"
            ::Opal.use_gem(gem, true)
          end
        end

        def self.source_map_enabled
          if @source_map_enabled.nil?
            check_version
            @source_map_enabled = config.source_maps? && development?
            ::Opal::Config.source_map_enabled = @source_map_enabled
          end
          @source_map_enabled
        end

        def self.source_map_server
          if source_map_enabled
            unless @source_map_server
              source_map_server  = ::Opal::SourceMapServer.new(sprockets.env, source_maps_prefix_path)
              ::Opal::Sprockets::SourceMapHeaderPatch.inject!(source_maps_prefix_path)
              @source_map_server = lambda do |env|
                # trace __FILE__, __LINE__, self, __method__, " SOURCE MAPS : PATH_INFO=#{env['PATH_INFO']}"
                sprockets.sync do
                  source_map_server.call(env)
                end
              end
            end
            @source_map_server
          end
        end

      end
    end
  end
end

