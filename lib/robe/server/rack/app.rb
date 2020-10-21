require 'rack-protection'
require 'rack/request'
require 'robe/server/rack/keep_alive'
require 'robe/server/rack/sprockets'
if Robe.config.development?
  require 'robe/server/rack/opal'
end
require 'robe/server/rack/html'

module Robe
  module Server
    module Rack
      class App
        extend Robe::Server::Rack::Paths
        
        def self.call(env)
          path = env['PATH_INFO']
          # trace __FILE__, __LINE__, self, __method__, " : path=#{path}"
          if %w[/ /index.html].include?(path)
            [200, { 'Content-Type' => 'text/html' }, [html.index]]
          else
            # trace __FILE__, __LINE__, self, __method__
            instance.call(env)
          end
        end

        def self.sprockets
          @sprockets ||= Robe::Server::Rack::Sprockets
        end

        def self.html
          @html ||= Robe::Server::Rack::Html
        end

        # Returns a ::Rack::App instance
        def self.instance
          build_instance unless @instance
          @instance
        end

        # not used yet
        # from https://github.com/josh/rack-ssl/blob/master/lib/rack/ssl.rb
        def self.redirect_to_https(env)
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

        def self.build_instance
          # local vars to overcome ::Rack::Builder.app instance_eval
          # _source_map_server = development? ? Robe::Server::Rack::Opal.source_map_server : nil
          Robe::Server::Rack::Opal.source_map_enabled # force Opal source maps setup
          _self = self
          _sprockets = sprockets
          @instance = ::Rack::Builder.app do
            use Robe::Server::Rack::KeepAlive # TODO: check this is useful
            use ::Rack::Deflater
            use ::Rack::ShowExceptions

            use ::Rack::Session::Cookie,
              key: 'rack.session',
              path: '/',
              expire_after: _self.config.session_expiry,
              secret: _self.config.app_secret

            use ::Rack::Protection

            # first map ruby, source map or asset files
            if _self.production?
              map File.join('/', _self.public_path) do
                run _sprockets.handle
              end
              map File.join('/', _self.public_assets_path) do
                run _sprockets.handle
              end
            else # development
              map(File.join('/', _self.assets_path)) do
                run _sprockets.handle
              end
              # OPAL/RUBY
              map(_self.opal_prefix_path) do
                run _sprockets.handle
              end
              # SOURCE MAPS
              if false # _source_map_server
                map(_self.source_maps_prefix_path) do
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
              run _self.redirect
            end
          end

        end

        # Redirect the browser to the root page
        # and provide 'route' parameters derived
        # from requested url/path.
        def self.redirect
          lambda do |env|
            path = env['PATH_INFO'][1..-1]
            trace __FILE__, __LINE__, self, __method__, " : #{path}"
            # [302, {'location' => "/#route=/#{path}" }, [] ]
            [302, {'location' => '/' }, [] ]
          end
        end

      end
    end
  end

  module_function

  def rack_app
    Robe::Server::Rack::App
  end
end

