require 'singleton'
require 'fileutils'
require 'yaml'
require 'opal'
require 'opal-sprockets' # for Opal >= 0.11, included in Opal 0.10
require 'rack-protection'
require 'rack/request'
require 'uglifier'
require 'robe/server/rack/keep_alive'

MIN_OPAL_VERSION = '0.10.5' # 0.11'

# Thanks to roda-opal_assets (Jamie Gaskins) for structure and code snippets.

module Opal::Sprockets::Processor
  module PlainJavaScriptLoader
    def self.call(input)
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
      class Assets
        include Singleton

        OPAL_PREFIX_PATH = '/__OPAL__'
        SOURCE_MAPS_PREFIX_PATH = '/__OPAL_SOURCE_MAPS__'

        def initialize
          unless Opal::VERSION >= MIN_OPAL_VERSION
            raise "Opal version must be >= #{MIN_OPAL_VERSION}"
          end
          @config = Robe::Server::Config
          build_rack_app
          precompile if config.precompile?
        end

        def call(env)
          path = env['PATH_INFO']
          # trace __FILE__, __LINE__, self, __method__, " : path=#{path}"
          if %w[/ /index.html].include?(path)
            [200, { 'Content-Type' => 'text/html' }, [index_html]]
          else
            # trace __FILE__, __LINE__, self, __method__
            @rack_app.call(env)
          end
        end

        # private

        # from https://github.com/josh/rack-ssl/blob/master/lib/rack/ssl.rb
        def scheme(env)
          if env['HTTPS'] == 'on'
            'https'
          elsif env['HTTP_X_FORWARDED_PROTO']
            env['HTTP_X_FORWARDED_PROTO'].split(',')[0]
          else
            env['rack.url_scheme']
          end
        end

          # from https://github.com/josh/rack-ssl/blob/master/lib/rack/ssl.rb
        def redirect_to_https(env)
          trace __FILE__, __LINE__, self, __method__
          req = ::Rack::Request.new(env)
          # trace __FILE__, __LINE__, self, __method__, " : req = #{req}"
          path, host, port = req.fullpath, req.host, req.port
          trace __FILE__, __LINE__, self, __method__, " : path=#{path} host=#{host} port=#{port}"
          if port
            port = ":#{port}"
            path = path.chop if path.end_with?('/')
          end
          location = "https://#{host}#{path}#{port}"
          trace __FILE__, __LINE__, self, __method__, " : location=#{location}"
          status  = %w[GET HEAD].include?(req.request_method) ? 301 : 307
          headers = { 'Content-Type' => 'text/html', 'Location' => location }
          [status, headers, []]
        end

        def assets_path
          config.assets_path
        end
        
        def build_rack_app
          # use local variables because of instance_eval in Rack blocks
          _config = config
          _source_map_enabled = Opal::Config.source_map_enabled = _config.source_maps? && development?
          _http_sprockets_lambda = http_sprockets_lambda
          _source_map_server = source_map_server if _source_map_enabled
          _redirect = redirect
          _production = production?

          @rack_app = ::Rack::Builder.app do
            use Robe::Server::Rack::KeepAlive # TODO: check this is useful
            use ::Rack::Deflater
            use ::Rack::ShowExceptions

            use ::Rack::Session::Cookie,
              key: 'rack.session',
              path: '/',
              expire_after: _config.session_expiry,
              secret: _config.app_secret

            use ::Rack::Protection

            # ASSETS
            map(File.join('/', _config.assets_path)) do
              run _http_sprockets_lambda
            end
            if _production
              map File.join('/', _config.public_path) do
                run _http_sprockets_lambda
              end
            else # development
              # OPAL/RUBY
              map(OPAL_PREFIX_PATH) do
                run _http_sprockets_lambda
              end
              # SOURCE MAPS
              if _source_map_enabled
                map(SOURCE_MAPS_PREFIX_PATH) do
                  use ::Rack::ConditionalGet
                  use ::Rack::ETag
                  run _source_map_server
                end
              end
            end

            # By now it's not assets, ruby or source_maps
            # so assume it's a browser request for a page.
            # As we're expecting only a single page app
            # (for now) we redirect the browser to the
            # root page and provide 'route' parameters.
            map('/') do
              run _redirect
            end
          end

        end

        # Redirect the browser to the root page
        # and provide 'route' parameters derived
        # from requested url/path.
        def redirect
          lambda do |env|
            path = env['PATH_INFO'][1..-1]
            # trace __FILE__, __LINE__, self, __method__, " : #{path}"
            # [302, {'location' => "/#route=/#{path}" }, [] ]
            [302, {'location' => '/' }, [] ]
          end
        end

        def not_found
          [404, {}, []]
        end

        def config
          @config
        end

        def precompile?
          config.precompile?
        end

        def production?
          config.production?
        end

        def development?
          config.development?
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
              #{font_tags}
              #{js_tags}
            </head> 
            <body>
              #{rb_tag}
            </body>
            </html>
          HTML
        end

        def http_sprockets_lambda
          @http_sprockets_lambda ||= if production?
            # no thread locking
            lambda do |env|
              trace __FILE__, __LINE__, self, __method__, " PATH_INFO=#{env['PATH_INFO']}"
              http_sprockets.call(env)
            end
          else
            # thread locking to stop sprockets concurrency issues in development
            lambda do |env|
              trace __FILE__, __LINE__, self, __method__, " PATH_INFO=#{env['PATH_INFO']}"
              http_sprockets_sync do
                http_sprockets.call(env)
              end
            end
          end
        end

        # ref: https://github.com/rails/sprockets/blob/master/guides/how_sprockets_works.md
        def http_sprockets
          unless @http_sprockets
            if development?
              register_opal_unaware_gems # do first so Opal::paths set
            end
            sprockets = ::Sprockets::Environment.new
            sprockets.logger.level = config.sprockets_logger_level
            if config.sprockets_memory_cache_size
              sprockets.cache = Sprockets::Cache::MemoryStore.new(config.sprockets_memory_cache_size)
            end
            if production?
              sprockets.append_path(config.public_path)
              sprockets.js_compressor = :uglifier
            else
              ::Opal.paths.each { |path| sprockets.append_path(path) }
              sprockets.append_path(config.rb_path)
            end
            sprockets.append_path(assets_path)
            @http_sprockets = sprockets
          end
          @http_sprockets
        end

        def prefix_opal(path)
          File.join(OPAL_PREFIX_PATH, path)
        end

        def source_map_server
          unless @source_map_server
            source_map_server  = ::Opal::SourceMapServer.new(http_sprockets, SOURCE_MAPS_PREFIX_PATH)
            ::Opal::Sprockets::SourceMapHeaderPatch.inject!(SOURCE_MAPS_PREFIX_PATH)
            @source_map_server = lambda do |env|
              trace __FILE__, __LINE__, self, __method__, " SOURCE MAPS : PATH_INFO=#{env['PATH_INFO']}"
              http_sprockets_sync do
                source_map_server.call(env)
              end
            end
          end
          @source_map_server
        end

        # To avoid concurrency problem in sprockets which results in
        # `RuntimeError: can't add a new key into hash during iteration.`
        # we sync all calls to sprockets - only in development?
        def http_sprockets_sync(&block)
          if production?
            block. call
          else
            (@sprockets_mutex ||= Mutex.new).synchronize(&block)
          end
        end

        def sprockets_asset_path(file_name, path, suffixes_regexp, suffix, compiled: production?)
          # sprockets expect the compiled suffix, e.g. .scss => .css, .rb => .js
          file_name = file_name.sub(suffixes_regexp, suffix)
          if compiled
            public_assets_file_path(file_name)
          else
            path = path.sub(assets_path, '')[1..-1] if production?
            File.join(path, file_name)
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

        def css_sprockets_paths(compiled: production?)
          css_file_names.map { |name|
            css_sprockets_path(name, compiled: compiled)
          }
        end

        def css_tag(file_name, media: :all)
          path = css_sprockets_path(file_name)
          %{<link href="#{path}" media="#{media}" rel="stylesheet" />}
        end

        def css_sprockets_path(file_name, compiled: production?)
          sprockets_asset_path(file_name, css_path, css_suffixes_regexp, '.css', compiled: compiled)
        end

        def css_path
          config.asset_paths[:css] || 'assets/css'
        end

        # anything in #css_path (e.g. 'assets/css') - no name check
        def css_file_names
          path = css_path
          unlisted = path && Dir.exists?(path) ? Dir.entries(path).reject{|e| e[0] == '.'} : []
          names = (config.css_file_order || []) | unlisted
          names = names.select { |name| name =~ css_suffixes_regexp }
          names
        end

        def css_suffixes_regexp
          @css_suffixes_regexp ||= Regexp.union(css_suffixes.map{|s| /#{s}$/})
        end

        def css_suffixes
          unless @css_suffixes
            @css_suffixes = http_sprockets.compressors['text/css'].keys.map { |s| ".#{s}" }
            @css_suffixes << '.css' unless @css_suffixes.include?('.css')
          end
          @css_suffixes
        end

        def font_path
          config.asset_paths[:font] || 'assets/fonts'
        end

        def font_tags
          ''.tap do |result|
            font_file_path_names.each do |path|
              result << font_tag(path) << "\n"
            end
          end
        end

        def font_tag(path)
          %{<link href="#{path}" type=#{'text/css'}" rel="stylesheet" />}
        end

        def font_file_path_names
          recursive_file_path_names(font_path)
        end

        def recursive_file_path_names(root)
          [].tap do |result|
            recurse_file_paths(root) do |path|
              result << path
            end
          end
        end

        def recurse_file_paths(root)
          if Dir.exists?(root)
            Dir[File.join(root, '**', '**')].each do |path|
              yield path if File.file?(path)
            end
          end
        end

        def js_tags
          @js_tags ||= ''.tap do |result|
            config.js_paths.each do |directory, file_names|
              resolve_js_file_names(directory, file_names).each do |file_name|
                result << js_tag(directory, file_name) << "\n"
              end
            end
          end
        end

        def js_sprockets_paths(compiled: production?)
          @js_sprockets_paths ||= [].tap do |result|
            config.js_paths.each do |directory, file_names|
              resolve_js_file_names(directory, file_names).each do |file_name|
                result << js_sprockets_path(directory, file_name, compiled: compiled)
              end
            end
          end
        end

        def js_tag(directory, file_name)
          path = js_sprockets_path(directory, file_name)
          %{<script src="#{path}"></script>}
        end

        def js_sprockets_path(directory, file_name, compiled: production?)
          sprockets_asset_path(file_name, File.join(assets_path, directory), js_suffixes_regexp, '.js', compiled: compiled)
        end

        def resolve_js_file_names(directory, file_names = nil)
          if file_names.nil? || file_names == '*'
            path = File.join(assets_path, directory)
            file_names = Dir.exists?(path) ? Dir.entries(path).reject{|e| e[0] == '.'} : []
            file_names = file_names.select { |e| e.end_with?('.js') }
            # if we don't strip the '.js' then any map files lead to an error in browser ??
            file_names = file_names.map { |e| e.sub('.js', '') }
            trace __FILE__, __LINE__, self, __method__, " directory=#{directory} file_names=#{file_names}"
          end
          file_names.select { |name| name =~ js_suffixes_regexp }
        end

        def js_suffixes_regexp
          @js_suffixes_regexp ||= Regexp.union(js_suffixes.map{|s| /#{s}$/})
        end

        def js_suffixes
          unless @js_suffixes
            @js_suffixes = http_sprockets.compressors['application/javascript'].keys.map { |s| ".#{s}" }
            @js_suffixes << '.js' unless @js_suffixes.include?('.js')
          end
          @js_suffixes
        end

        def rb_tag
          if production?
            js_path = File.split(config.client_app_rb_path).last.sub('.rb', '') + '.js'
            js_path = public_assets_file_path(js_path)
            %{<script src="#{js_path}"></script>\n}
          else
            opal_js_tags
          end
        end

        # Adapted from Opal::Sprockets##javascript_include_tag
        # so we can see/control what we're doing...
        def opal_js_tags
          rb_path = config.client_app_rb_path
          tags = []
          if config.source_maps?
            asset = http_sprockets[rb_path]
            puts "#{__FILE__}[#{__LINE__}] #{self.class}##{__method__}: Cannot find asset: #{rb_path}" if asset.nil?
            raise "Cannot find asset: #{rb_path}" if asset.nil?
            asset.to_a.map do |dependency|
              # trace __FILE__, __LINE__, self, __method__, " "
              tags << %{<script src="#{prefix_opal(dependency.logical_path)}?body=1"></script>}
            end
          else
            tags << %{<script src="#{prefix_opal(rb_path.sub('.rb', ''))}.js"></script>}
          end
          tags << %{<script>#{::Opal::Sprockets.load_asset(rb_path)}</script>}
          # trace __FILE__, __LINE__, self, __method__, " tags = #{tags}"
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
          @public_assets_path ||= File.join(config.public_path, config.public_assets_path)
        end

        def precompile
          compiler_sprockets # set up all sprockets paths, including opal/ruby paths
          reset_public_assets_dir
          link_uncompiled_files
          compile_files
          @compiler_sprockets = nil
        end

        def reset_public_assets_dir
          FileUtils.remove_dir(public_assets_path, true)
          FileUtils.mkdir_p(public_assets_path)
        end

        def compile_files
          paths_to_compile.each do |path|
            trace __FILE__, __LINE__, self, __method__, " path=#{path}"
            puts "Compiling #{path}..."
            asset_name = File.split(path).last.sub('.rb', '.js')
            compile_file(path, asset_name)
            puts '...done'
          end
        end

        def link_uncompiled_files
          root = http_sprockets.root
          public_assets_path = File.join(root, self.public_assets_path)
          uncompiled_asset_paths.each do |target_path|
            target_path = File.join(root, target_path)
            FileUtils.ln_s(target_path, public_assets_path)
          end
        end

        def uncompiled_asset_paths
          [].tap do |paths|
            config.asset_paths.values.each do |asset_path|
              paths << asset_path unless asset_path.end_with?('js') || asset_path.end_with?('css')
            end
          end
        end

        def paths_to_compile
          [].tap do |result|
            result.concat css_sprockets_paths(compiled: false)
            result.concat js_sprockets_paths(compiled: false)
            result.concat rb_file_names
          end
        end

        def public_assets_file_path(file_name, create_dir: false)
          dir = File.join(public_assets_path, file_name.split('.').last)
          FileUtils.mkdir_p(dir) if create_dir
          File.join(dir, file_name)
        end

        # sprockets expects the compiled file name...
        # lots of magic happening in opal-sprockets when we get the compiled asset
        # from sprockets[compiled_file_name] - this is where opal compiles everything
        def compile_file(path, asset_name)
          trace __FILE__, __LINE__, self, __method__, " : path=#{path}"
          compiled_contents = if path.end_with?('.rb')
            compile_with_builder(path)
          else
            result = compiler_sprockets[path]
            raise "could not find #{path} in sprockets" unless result
            result
          end
          # trace __FILE__, __LINE__, self, __method__, " : asset_name=#{asset_name}"
          compiled_contents = compiled_contents.to_s
          output_path = public_assets_file_path(asset_name, create_dir: true)
          # trace __FILE__, __LINE__, self, __method__, " : #{compiled_file_name} => writing #{compiled_contents.size} bytes to #{output_path}"
          if asset_name.end_with?('.js')
            trace __FILE__, __LINE__, self, __method__, " : BEFORE UGLIFIER : #{output_path} : compiled_contents.size=#{compiled_contents.size}"
            compiled_contents = ::Uglifier.compile(compiled_contents, compress: {passes: 3})
            trace __FILE__, __LINE__, self, __method__, " : AFTER UGLIFIER : #{output_path} : compiled_contents.size=#{compiled_contents.size}"
            # compiled_contents = Compile::TreeShake.compile(compiled_contents)
            # trace __FILE__, __LINE__, self, __method__, " : TREE SHAKE : #{path} : compiled_contents.size=#{compiled_contents.size}"
          end
          File.write(output_path, compiled_contents)
          nil
        end

        # ref: https://github.com/rails/sprockets/blob/master/guides/how_sprockets_works.md
        def compiler_sprockets
          unless @compiler_sprockets
            register_opal_unaware_gems # do first so Opal::paths set
            sprockets = ::Sprockets::Environment.new
            sprockets.logger.level = config.sprockets_logger_level
            if config.sprockets_memory_cache_size
              sprockets.cache = Sprockets::Cache::MemoryStore.new(config.sprockets_memory_cache_size)
            end
            ::Opal.paths.each { |path| sprockets.append_path(path) }
            sprockets.append_path(config.rb_path)
            sprockets.append_path(assets_path)
            @compiler_sprockets = sprockets
          end
          @compiler_sprockets
        end

        def compile_with_builder(sprockets_path)
          sprockets_path = sprockets_path.sub('.js', '')
          trace __FILE__, __LINE__, self, __method__, " : sprockets_path=#{sprockets_path}"
          Opal.append_path('lib')
          Opal::Builder.build(sprockets_path).to_s
        end
      end
    end
  end

  module_function

  def assets
    @assets ||= Robe::Server::Rack::Assets.instance
  end
end

