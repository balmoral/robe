require 'robe/server/rack/config'

module Robe
  module Server
    module Rack
      module Paths
        include Robe::Server::Rack::Config

        OPAL_PREFIX_PATH = '/__OPAL__'
        SOURCE_MAPS_PREFIX_PATH = '/__OPAL_SOURCE_MAPS__'

        def opal_prefix_path
          OPAL_PREFIX_PATH
        end
        
        def source_maps_prefix_path
          SOURCE_MAPS_PREFIX_PATH
        end

        def assets_path
          config.assets_path
        end

        def asset_paths
          config.asset_paths
        end

        def prefix_opal(path)
          File.join(OPAL_PREFIX_PATH, path)
        end

        def sprockets
          @sprockets ||= Robe::Server::Rack::Sprockets
        end

        def sprockets_asset_path(file_name, path, suffixes_regexp, suffix)
          # sprockets expects the compiled suffix, e.g. .scss => .css, .rb => .js
          file_name = file_name.sub(suffixes_regexp, suffix)
          File.join(path, file_name)
        end

        def css_sprockets_paths
          css_file_names.map { |name|
            css_sprockets_path(name)
          }
        end

        def css_sprockets_path(file_name)
          sprockets_asset_path(file_name, css_path, css_suffixes_regexp, '.css')
        end

        def css_path
          asset_paths[:css] || 'assets/css'
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
            @css_suffixes = sprockets.env.compressors['text/css'].keys.map { |s| ".#{s}" }
            @css_suffixes << '.css' unless @css_suffixes.include?('.css')
          end
          @css_suffixes
        end

        def font_path
          asset_paths[:font] || 'assets/fonts'
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

        def js_sprockets_paths
          @js_sprockets_paths ||= [].tap do |result|
            config.js_paths.each do |directory, file_names|
              resolve_js_file_names(directory, file_names).each do |file_name|
                result << js_sprockets_path(production? ? 'js'  : directory, file_name)
              end
            end
          end
        end

        def js_sprockets_path(directory, file_name)
          sprockets_asset_path(file_name, File.join(assets_path, directory), js_suffixes_regexp, '.js')
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
            @js_suffixes = sprockets.env.compressors['application/javascript'].keys.map { |s| ".#{s}" }
            @js_suffixes << '.js' unless @js_suffixes.include?('.js')
          end
          @js_suffixes
        end

        def rb_file_names
          [config.client_app_rb_path]
        end

        def public_path
          @public_path ||= config.public_path
        end

        def public_assets_path
          @public_assets_path ||= config.public_assets_path
        end

        def public_assets_full_path
          @public_assets_full_path ||= File.join(public_path, public_assets_path)
        end

        def public_assets_file_path(file_name, create_dir: false)
          dir = File.join(public_assets_full_path, file_name.split('.').last)
          FileUtils.mkdir_p(dir) if create_dir
          File.join(dir, file_name)
        end

      end
    end
  end
end

