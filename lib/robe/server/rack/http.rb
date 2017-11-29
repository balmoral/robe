require 'yaml'
require 'opal'
require 'opal-sprockets' # for Opal >= 0.11, included in Opal 0.10
require 'rack-protection'
# require 'uglifier' if ENV['RACK_ENV'] == 'production'

MIN_OPAL_VERSION = '0.10.5' # 0.11'

# TODO: see opal-sprockets server.rb for ideas

module Robe
  module Server
    class Http
      SOURCE_MAPS_PREFIX_PATH = '/__OPAL_SOURCE_MAPS__'

      def self.instance
        @instance ||= new
      end

      def initialize
        unless Opal::VERSION >= MIN_OPAL_VERSION
          raise "Opal version must be >= #{MIN_OPAL_VERSION}"
        end
        @rack_env = (ENV['RACK_ENV'] || :development).to_sym
        @config = Robe::Server::Config
        # trace __FILE__, __LINE__, self, __method__, " : @rack_env=#{@rack_env} @config=#{@config}"
        init_rack_app
        precompile if production?
      end

      def call(env)
        path = env['PATH_INFO']
        # trace __FILE__, __LINE__, self, __method__, " : path=#{path}"
        if %w[/ /index.html].include?(path)
          # trace __FILE__, __LINE__, self, __method__
          [200, { 'Content-Type' => 'text/html' }, [index_html]]
        else
          # trace __FILE__, __LINE__, self, __method__
          @rack_app.call env
        end
      end

      private

      def init_rack_app
        # local variables because of instance_eval in Rack blocks
        _config = config
        _source_map_enabled = Opal::Config.source_map_enabled = _config.source_maps? && development?
        # trace __FILE__, __LINE__, self, __method__, " _source_map_enabled=#{_source_map_enabled}"
        _sprockets_lambda = sprockets_lambda
        _source_map_server = source_map_server if _source_map_enabled
        _rack = rack
        _reload = reload
        _production = production?
        @rack_app = Rack::Builder.app do
          use Rack::Deflater
          use Rack::ShowExceptions

          use Rack::Session::Cookie,
            key: 'rack.session',
            expire_after: _config.session_expiry,
            secret: _config.app_secret
          use Rack::Protection

          if _source_map_enabled
            map(SOURCE_MAPS_PREFIX_PATH) do
              use Rack::ConditionalGet
              use Rack::ETag
              run _source_map_server
            end
          end

          # TODO: better than this
          map('/page') do
            run _reload
          end

          map('/assets') do
            run _sprockets_lambda
          end
          
          if _production
            run _rack
          else
            map('/') do
              run _sprockets_lambda
            end
          end
        end
      end

      def reload
        lambda do |env|
          trace __FILE__, __LINE__, self, __method__, " : #{env['PATH_INFO']}"
          [302, {'location' => '/'}, [] ]
        end
      end

      def rack
        # The Rack::Static middleware intercepts requests for static files
        # (javascript files, images, stylesheets, etc)
        # based on the url prefixes or route mappings passed in the options,
        # and serves them using a Rack::File object.
        #
        # This allows a Rack stack to serve both static and dynamic content.
        #
        # ref: http://www.rubydoc.info/gems/rack/Rack/Static
        rack = ::Rack::Static.new(
          lambda { |_env| not_found },
          urls: ['', 'assets'],
          root: production? ? '/public' : '/'
        )
        lambda do |env|
          trace __FILE__, __LINE__, self, __method__, " : run _rack : #{env['PATH_INFO']}"
          rack.call(env)
        end
      end

      def not_found
        [404, {}, []]
      end

      def rack_env
        @rack_env
      end

      def config
        @config
      end

      def minify?
        production?
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
          <body>
            #{rb_tag}
          </body>
          </html>
        HTML
      end

      def sprockets_lambda
        unless @sprockets_lambda
          @sprockets_lambda = lambda do |env|
            sprockets_sync do
              sprockets.call(env)
            end
          end
        end
        @sprockets_lambda
      end

      # ref: https://github.com/rails/sprockets/blob/master/guides/how_sprockets_works.md
      def sprockets
        unless @sprockets
          register_opal_unaware_gems # do first so Opal::paths set
          sprockets = ::Sprockets::Environment.new
          sprockets.logger.level = config.sprockets_logger_level
          if config.sprockets_memory_cache_size
            sprockets.cache = Sprockets::Cache::MemoryStore.new(config.sprockets_memory_cache_size)
          end
          ::Opal.paths.each { |path| sprockets.append_path(path) }
          sprockets.append_path(config.assets_path)
          sprockets.append_path(config.rb_path)
          sprockets.js_compressor = :uglifier if minify?
          @sprockets = sprockets
        end
        @sprockets
      end

      def source_map_server
        unless @source_map_server
          source_map_server  = ::Opal::SourceMapServer.new(sprockets, SOURCE_MAPS_PREFIX_PATH)
          ::Opal::Sprockets::SourceMapHeaderPatch.inject!(SOURCE_MAPS_PREFIX_PATH)
          @source_map_server = lambda do |env|
            sprockets_sync do
              source_map_server.call(env)
            end
          end
        end
        @source_map_server
      end

      # To avoid concurrency problem in sprockets which results in
      # `RuntimeError: can't add a new key into hash during iteration.`
      # we sync all calls to sprockets - only in development?
      def sprockets_sync(&block)
        if production?
          block. call
        else  
          (@sprockets_mutex ||= Mutex.new).synchronize(&block)
        end
      end

      def pwd
        @pwd ||= Dir.pwd
      end

      def css_tags
        ''.tap do |result|
          css_file_names.each do |name|
            result << css_tag(name) << "\n"
          end
        end
      end

      def css_tag(file_name, media: :all)
        path = if production?
          precompiled_path(file_name)
        else
          File.join('css', file_name.sub(css_suffixes_regexp, '.css'))
        end
        %{<link href="#{path}" media="#{media}" rel="stylesheet" />}
      end

      def css_path
        config.app_asset_paths[:css] || 'assets/css'
      end

      # anything in #css_path (e.g. 'assets/css') - no name check
      def css_file_names
        path = css_path
        unlisted = path && Dir.exists?(path) ? Dir.entries(path).reject{|e| e[0] == '.'} : []
        names = (config.css_file_order || []) | unlisted
        names.select { |name| name =~ css_suffixes_regexp }
      end

      def css_suffixes_regexp
        @css_suffixes_regexp ||= Regexp.union(css_suffixes.map{|s| /#{s}$/})
      end

      def css_suffixes
        unless @css_suffixes
          @css_suffixes = sprockets.compressors['text/css'].keys.map { |s| ".#{s}" }
          @css_suffixes << '.css' unless @css_suffixes.include?('.css')
        end
        @css_suffixes
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
          File.join('js', js_file_name.sub(js_suffixes_regexp, '')), # no suffix - otherwise screws up in opal sprockets
          sprockets: sprockets,
          prefix: '',
          debug: false
        )
      end

      def js_path
        config.app_asset_paths[:js] || 'assets/js'
      end

      def js_file_names
        path = js_path
        unlisted = path && Dir.exists?(path) ? Dir.entries(path).reject{|e| e[0] == '.'} : []
        names = (config.js_file_order || []) | unlisted
        names.select { |name| name =~ js_suffixes_regexp }
      end

      def js_suffixes_regexp
        @js_suffixes_regexp ||= Regexp.union(js_suffixes.map{|s| /#{s}$/})
      end

      def js_suffixes
        unless @js_suffixes
          @js_suffixes = sprockets.compressors['application/javascript'].keys.map { |s| ".#{s}" }
          @js_suffixes << '.js' unless @css_suffixes.include?('.js')
        end
        @js_suffixes
      end

      def rb_tag
        if production?
          rb_path = File.split(config.client_app_rb_path).last.sub('.rb', '') + '.js'
          %{<script src="#{precompiled_path(rb_path)}"></script>\n}
        else
          opal_js_tags
        end
      end

      # Adapted from Opal::Sprockets##javascript_include_tag
      # so we can see what we're doing...
      def opal_js_tags
        rb_path = config.client_app_rb_path
        tags = []
        if config.source_maps?
          asset = sprockets[rb_path]
          puts "#{__FILE__}[#{__LINE__}] #{self.class}##{__method__}: Cannot find asset: #{rb_path}" if asset.nil?
          raise "Cannot find asset: #{rb_path}" if asset.nil?
          asset.to_a.map do |dependency|
            tags << %{<script src="#{dependency.logical_path}?body=1"></script>}
          end
        else
          tags << %{<script src="#{rb_path.sub('.rb', '')}.js"></script>}
        end
        tags << %{<script>#{::Opal::Sprockets.load_asset(rb_path)}</script>}
        tags.join("\n")
      end

      def rb_file_names
        [config.client_app_rb_path]
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

      def public_assets_path
        config.public_assets_path
      end

      def precompile
        files = []
        files += css_file_names
        files += js_file_names
        files += rb_file_names.map { |f| f.sub('.rb', '') + '.js' }

        FileUtils.mkdir_p(public_assets_path)

        assets = files.each_with_object({}) do |file, hash|
          asset = sprockets[file]
          trace __FILE__, __LINE__, self, __method__, " : asset.digest_path=#{asset.digest_path}"
          puts "Compiling #{file}..."
          source_file_name = file.split('/').last
          compiled_file_name = asset.digest_path.split('/').last
          hash[source_file_name] = compiled_file_name
          compile_file(file, "#{public_assets_path}/#{compiled_file_name}")
          puts '...done'
        end

        puts "#{__FILE__}[#{__LINE__}] : assets=#{assets}"
        File.write('assets.yml', YAML.dump(assets))
      end

      def precompiled_path(file)
        config_file = precompiled_config[file]
        raise "'#{file}' not found in assets.yml: " unless config_file
        "#{public_assets_path}/#{config_file}"
      end

      def precompiled_config
        unless defined?(@precompiled_config)
          @precompiled_config = YAML.load_file('assets.yml')
          unless @precompiled_config
            warn 'Precompiled assets config is broken'
          end
          # trace __FILE__, __LINE__, self, __method__, " : @precompiled_config => #{@precompiled_config}"
        end
        @precompiled_config
      end

      def compile_file(source_file_name, output_filename)
        opal_code = Opal::Sprockets.load_asset(source_file_name)
        compiled = sprockets[source_file_name].to_s + opal_code
        trace __FILE__, __LINE__, self, __method__, " : #{source_file_name} => writing #{compiled.size} bytes to #{output_filename}"
        File.write(output_filename, compiled)
        nil
      end

    end
  end

  module_function

  def http
    @http ||= Robe::Server::Http.instance
  end
end

