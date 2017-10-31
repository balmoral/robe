require 'singleton'
require 'yaml'
require 'opal'
require 'opal-sprockets' # for Opal >= 0.11, included in Opal 0.10
require 'sprockets-sass'
require 'sass'
require 'uglifier' if ENV['RACK_ENV'] == 'production'

MIN_OPAL_VERSION = '0.11'

# TODO: see opal-sprockets server.rb for ideas

module Robe
  module Server
    class Assets
      include Singleton

      def initialize
        unless Opal::VERSION >= MIN_OPAL_VERSION
          raise "Opal version must be >= #{MIN_OPAL_VERSION}"
        end
        @rack_env = (ENV['RACK_ENV'] || :development).to_sym
        @minify = production?
        @config = Robe::Server::Config
        # puts "#{__FILE__}[#{__LINE__}] : @rack_env=#{@rack_env} @minify=#{@minify} @config=#{@config}"
        init_source_maps
        register_opal_unaware_gems
        precompile if production?
      end

      def route(r)
        # puts "#{__FILE__}[#{__LINE__}] #{self.class.name}##{__method__} : r=>#{r.inspect}"
        r.get 'favicon.ico' do
           ''
        end
        unless production?
          targets.each do |target, folders|
            folders.each do |folder|
              # trace __FILE__, __LINE__, self, __method__, " : target=#{target} folder='#{folder}' "
              r.on folder do
                if folder == 'public'
                  r.on 'assets' do
                    # trace __FILE__, __LINE__, self, __method__, " : public/assets "
                    env = send(target)
                    # trace __FILE__, __LINE__, self, __method__, " : env=#{env}"
                    r.run env
                  end
                else
                  # trace __FILE__, __LINE__, self, __method__, " : MATCH for #{target}"
                  env = send(target)
                  # trace __FILE__, __LINE__, self, __method__, " : env=#{env}"
                  r.run env
                end
              end
            end
          end
        end
        r.root do # load for any path other than assets requests above
          # trace __FILE__, __LINE__, self, __method__, ' : r.root=> index_html'
          index_html
        end
      end

      private

      def rack_env
        @rack_env
      end

      def config
        @config
      end

      def minify?
        @minify
      end

      def production?
        rack_env == :production
      end

      def development?
        !production? # rack_env == :development
      end

      def index_html
        # trace __FILE__, __LINE__, self, __method__
        <<-HTML
          <!DOCTYPE html>
          <html>
          <head>
            #{config.html_literal_head}
            <title>#{config.title}</title>
            #{css_tags}
            #{js_tags}
          </head>
            #{rb_tag}
          </html>
        HTML
      end

      def sprockets
        unless @sprockets
          @sprockets = ::Sprockets::Environment.new
          # memory store is much faster than file store
          @sprockets.cache = Sprockets::Cache::MemoryStore.new(4096) # default is only 1000
          # @sprockets.cache = Sprockets::Cache::FileStore.new('/tmp', 50 * 1024 * 1024)
          Opal.paths.each do |path|
            # trace __FILE__, __LINE__, self, __method__, " @sprockets.append_path #{path}"
            @sprockets.append_path(path)
          end
          config.app_asset_paths.values.flatten.each do |path|
            # trace __FILE__, __LINE__, self, __method__, " @sprockets.append_path #{path}"
            @sprockets.append_path(path)
          end
          @sprockets.js_compressor = :uglifier if minify?
          # @sprockets.append_path('/public/assets') if production?
        end
        @sprockets
      end

      def targets
        @targets ||= if production?
          {
            sprockets: %w(public) # %w(/public/assets/)
          }
        else
          {
            source_map_server: [source_map_prefix[1..-1]],
            sprockets: config.app_asset_paths.values.flatten
          }
        end
      end

      def css_tags
        ''.tap do |result|
          css_file_names.each do |f|
            result << css_tag(f) << "\n"
          end
        end
      end

      def css_tag(file_name, media: :all)
        path = if production?
          precompiled_path(file_name)
        else
          asset = sprockets[file_name]
          raise "File not found: #{file}" if asset.nil?
          asset.filename.to_s.sub(Dir.pwd, '')
        end
        %{<link href="#{path}" media="#{media}" rel="stylesheet" />}
      end

      def css_path
        config.app_asset_paths[:css] || 'assets/css'
      end

      def css_file_names
        # puts "config.css_file_order=#{config.css_file_order}"
        path = css_path
        unlisted = path ? Dir.entries(path).select{|e| e.end_with?('.css')} : []
        (config.css_file_order || []) | unlisted
      end

      def js_tags
        ''.tap do |result|
          js_file_names.each do |name|
            result << if production?
              %{<script src="#{precompiled_path(file)}"></script>\n}
            else
              js_tag(name)
            end
          end
        end
      end

      def js_tag(js_file_name)
        ::Opal::Sprockets.javascript_include_tag(
          js_file_name.sub('.js', ''), # otherwise screws up in opal sprockets
          sprockets: sprockets,
          prefix: js_path,
          debug: false
        )
      end

      def js_path
        config.app_asset_paths[:js] || 'assets/js'
      end

      def js_file_names
        path = js_path
        unlisted = path ? Dir.entries(path).select{|e| e.end_with?('.js')} : []
        (config.js_file_order || []) | unlisted
      end

      def rb_tag
        rb_file_name = config.client_app_path
        if production?
          rb_file_name = file.sub('.rb', '') + '.js'
          %{<script src="#{precompiled_path(rb_file_name)}"></script>\n}
        else
          debug = Opal::Config.source_map_enabled
          rb_file_name = rb_file_name.sub('.rb', '') unless debug # patch for opal sprockets
          ::Opal::Sprockets.javascript_include_tag(
            rb_file_name,
            sprockets: sprockets,
            prefix: rb_path,
            debug: debug
          )
        end
      end

      def rb_path
        config.app_asset_paths[:rb] || 'lib'
      end

      # Tell Opal about all gems which aren't Opal aware.
      # Gems which are Opal aware set load paths within Opal.
      def register_opal_unaware_gems
        config.opal_unaware_gems.each do |gem|
          # trace __FILE__, __LINE__, self, __method__, " : calling Opal.use_gem(#{gem}, true)"
          Opal.use_gem(gem, true)
        end
      end

      def source_map_prefix
        '/__OPAL_SOURCE_MAPS__'
      end

      def init_source_maps
        if Opal::Config.source_map_enabled = config.source_maps? && development?
          trace __FILE__, __LINE__, self, __method__, ' > > > > > SOURCE MAPS ENABLED < < < < <'
          ::Opal::Sprockets::SourceMapHeaderPatch.inject!(source_map_prefix)
          opal_source_map_server = Opal::SourceMapServer.new(sprockets, source_map_prefix)
          builder = Rack::Builder.new do
            use Rack::ConditionalGet
            use Rack::ETag
            run opal_source_map_server
          end
          mutex = Mutex.new
          @source_map_server = ->(env) do
            mutex.synchronize do
              builder.call(env)
            end
          end
        end
      end

      def source_map_server
        @source_map_server
      end

      def precompile
        rb_files = [rb_file]
        files = css_file_names +
          js_file_names +
          rb_files.map { |f| f.sub('.rb', '') + '.js' }

        FileUtils.mkdir_p('public/assets')

        assets = files.each_with_object({}) do |file, hash|
          print "Compiling #{file}..."
          asset = sprockets[file]
          hash[file] = asset.digest_path
          compile_file(file, "public/assets/#{asset.digest_path}")
          puts ' done'
        end

        puts "#{__FILE__}[#{__LINE__}] : assets=#{assets}"
        File.write('assets.yml', YAML.dump(assets))
      end

      def precompiled_path(file)
        config_file = precompiled_config[file]
        unless config_file
          raise "file not found in config: #{file}"
        end
        "/public/assets/#{config_file}"
      end

      def precompiled_config
        unless defined?(@precompiled_config)
          @precompiled_config = YAML.load_file('assets.yml')
          unless @precompiled_config
            warn 'Precompiled assets config is broken'
          end
        end
        @precompiled_config
      end

      def compile_file(rb_file_name, output_filename)
        opal_code = Opal::Sprockets.load_asset(rb_file_name)
        compiled = sprockets[rb_file_name].to_s + opal_code
        File.write(output_filename, compiled)
        nil
      end

    end
  end

  module_function

  def assets
    @assets ||= Robe::Server::Assets.instance
  end
end

