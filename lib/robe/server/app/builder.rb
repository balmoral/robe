require 'fileutils'
require 'robe/server/rack/opal' # brings sprockets

module Robe
  module Server
    class App
      class Builder
        extend Robe::Server::Rack::Paths
        
        def self.build
          save_rack_env = ENV['RACK_ENV']
          ENV['RACK_ENV'] = 'development'
          self.build = true # in Robe:Server::Rack::Config
          trace __FILE__, __LINE__, self, __method__, " build?=#{build?}"
          begin
            reset_public_assets_dir
            copy_uncompiled_files
            compile_files
          ensure
            self.build = false
            ENV['RACK_ENV'] = save_rack_env
          end
        end

        def self.opal
          @@opal ||= Robe::Server::Rack::Opal
        end

        def self.sprockets
          @@sprockets ||= opal.sprockets
        end

        def self.reset_public_assets_dir
          FileUtils.remove_dir(public_assets_full_path, true)
          FileUtils.mkdir_p(public_assets_full_path)
        end

        def self.compile_files
          paths_to_compile.each do |path|
            trace __FILE__, __LINE__, self, __method__, " path=#{path}"
            puts "Compiling #{path}..."
            asset_name = File.split(path).last.sub('.rb', '.js')
            compile_file(path, asset_name)
            puts '...done'
          end
        end

        # Compile is done through Opal for all files,
        # including css, scss, js, ...
        # Lots of magic happening in opal-sprockets when we get the compiled asset
        # from sprockets[compiled_file_name] - this is where opal compiles everything.
        # Sprockets expects the compiled file name...
        def self.compile_file(path, asset_name)
          trace __FILE__, __LINE__, self, __method__, " : path=#{path}"
          compiled_contents = if path.end_with?('.rb')
            opal.compile_with_builder(path)
          else
            result = sprockets.env[path]
            raise "could not find #{path} in sprockets.env.paths=#{sprockets.env.paths}" unless result
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

        def self.copy_uncompiled_files
          root = sprockets.env.root
          public_assets_full_path = File.join(root, self.public_assets_full_path)
          uncompiled_asset_paths.each do |target_path|
            target_path = File.join(root, target_path)
            FileUtils.mkdir_p(File.dirname(target_path))
            FileUtils.cp(target_path, public_assets_full_path)
          end
        end

        def self.uncompiled_asset_paths
           [].tap do |paths|
             asset_paths.values.each do |asset_path|
               paths << asset_path unless asset_path.end_with?('js') || asset_path.end_with?('css')
             end
           end
        end

        def self.paths_to_compile
          [].tap do |result|
            result.concat css_sprockets_paths
            result.concat js_sprockets_paths
            result.concat rb_file_names
          end
        end

      end
    end
  end
end