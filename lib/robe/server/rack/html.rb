require 'rack-protection'
require 'rack/request'
require 'robe/server/rack/keep_alive'
require 'robe/server/rack/sprockets'
if Robe.config.development?
  require 'robe/server/rack/opal'
end

module Robe
  module Server
    module Rack
      class Html
        extend Robe::Server::Rack::Paths
        
        def self.sprockets
          @sprockets ||= Robe::Server::Rack::Sprockets
        end
        
        def self.index
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
                 #{rb_tags}
               </body>
             </html>
           HTML
        end
        
        def self.css_tags
          ''.tap do |result|
            css_file_names.each do |name|
              result << css_tag(name) << "\n"
            end
          end
        end

        def self.css_tag(file_name, media: :all)
          path = css_sprockets_path(file_name)
          %{<link href="#{path}" media="#{media}" rel="stylesheet" />}
        end

        def self.js_tags
          ''.tap do |result|
            js_sprockets_paths.each do |path|
              result << js_tag(path) << "\n"
            end
          end
        end

        def self.js_tag(path)
          %{<script src="#{path}"></script>}
        end

        def self.opal
          @opal ||= development? ? Robe::Server::Rack::Opal : nil
        end
        
        # Adapted from Opal::Sprockets##javascript_include_tag
        # so we can see/control what we're doing...
        def self.rb_tags
          if production?
            js_tag(js_sprockets_path('js', 'app.js'))
          else
            rb_path = config.client_app_rb_path
            tags = []
            if config.source_maps?
              asset = opal.sprockets.env[rb_path]
              # puts "#{__FILE__}[#{__LINE__}] #{self.class}##{__method__}: Cannot find asset: #{rb_path}" if asset.nil?
              abort "Cannot find asset: #{rb_path}" if asset.nil?
              asset.to_a.map do |dependency|
                # trace __FILE__, __LINE__, self, __method__, " : dependency=#{dependency} "
                tags << %{<script src="#{prefix_opal(dependency.logical_path)}?body=1"></script>}
              end
            else
              tags << %{<script src="#{prefix_opal(rb_path.sub('.rb', ''))}.js"></script>}
            end
            tags << %{<script>#{opal.load_asset(rb_path)}</script>}
            # trace __FILE__, __LINE__, self, __method__, " tags = #{tags}"
            tags.join("\n")
          end
        end

      end
    end
  end
end

