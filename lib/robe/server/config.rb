require 'securerandom'
require 'logger'

module Robe
  module Server
    class Config

      class << self

        def app_secret
          @app_secret ||= (
            ENV['APP_SECRET'] ||
            SecureRandom.hex(64)
          )
        end

        def app_secret=(string)
          @app_secret = string
        end

        # Defaults to 30 days
        def session_expiry
          @session_expiry ||= 30 * 24 * 60 * 60
        end

        def session_expiry=(seconds)
          @session_expiry = seconds
        end

        def favicon=(path)
          @favicon = path
        end

        def favicon
          @favicon
        end

        def source_maps?
          if @source_maps.nil?
            @source_maps = ENV['RACK_ENV'] == 'development'
          end
          @source_maps
        end

        def source_maps=(bool)
          @source_maps = bool
        end

        def use_mongo?
          !!@use_mongo
        end

        def use_mongo=(b)
          # puts "#{__FILE__}[#{__LINE__}] #{self.name}###{__method__}(#{b})"
          @use_mongo = b
        end

        # nil will use default
        def mongo_hosts
          @mongo_hosts
        end

        # should include port
        # e.g. '127.0.0.1:27017'
        # e.g. 'xy123456-a0.mongolab.com:49664'
        def mongo_host=(h)
          @mongo_hosts = [h]
        end

        # multiple hosts for replica sets...
        # should include ports
        # e.g. ['xy123456-a0.mongolab.com:49664', 'xy654321-a0.mongolab.com:49664']
        def mongo_hosts=(h)
          @mongo_hosts = h.to_a
        end

        def mongo_database
          @mongo_database
          # fail "#{self.name}###{__method__} must be set if mongo is used"
        end

        def mongo_database=(s)
          @mongo_database = s
        end

        def mongo_user
          @mongo_user
        end

        def mongo_user=(user)
          @mongo_user = user
        end

        def mongo_password
          @mongo_password
        end

        def mongo_password=(password)
          @mongo_password = password
        end

        # Directory structure is conventionally:
        # |-- .
        # |   |-- assets
        # |       |-- css
        # |       |-- fonts
        # |       |-- images
        # |       |-- js
        # |       |-- keys
        # |   |-- lib
        # |       |-- app-name
        # |           |-- client
        # |           |-- common
        # |           |-- server
        # |-- config.ru
        # |-- Gemfile
        # |-- Procfile
        #

        def assets_path
          @assets_path ||= 'assets'
        end
        
        def assets_path=(path)
          @assets_path = path
        end

        def rb_path
          @rb_path ||= 'lib'
        end

        def rb_path=(path)
          @rb_path = path
        end

        def client_app_rb_path
          unless @client_app_rb_path
            raise "Set `config.client_app_rb_path = 'app-name/client/app.rb'` as required in the #configure method of your Robe::Server::App subclass."
          end
          @client_app_rb_path
        end

        # Set path to client-side app file within #rb_path.
        # Conventionally 'app-name/client/app.rb'.
        def client_app_rb_path=(n)
          @client_app_rb_path = n
        end

        # Default is 'public/assets'
        def public_assets_path
          @public_assets_path ||= 'public/assets'
        end

        def public_assets_path=(path)
          @public_assets_path = path
        end

        def title
          @title ||= 'RoBE App'
        end

        def title=(t)
          @title = t
        end

        def html_literal_head
          @html_literal_head ||= <<-HTML
            <meta charset="utf-8">
            <meta content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0' name='viewport' />
            <meta http-equiv="x-ua-compatible" content="ie=edge"/>    
            <script src="https://code.jquery.com/jquery-3.2.1.min.js" integrity="sha256-hwg4gsxgFZhOsEEamdOYGBf13FyQuiTwlAQgxVSNgt4=" crossorigin="anonymous"></script>
          HTML
        end

        def html_literal_head=(h)
          @html_literal_head = h
        end

        def html_literal_scripts
          @html_literal_scripts ||= <<-HTML
          HTML
        end

        def html_literal_scripts(s)
          @html_literal_scripts = s
        end

        def app_asset_paths
          @app_asset_paths ||= {
            css: 'assets/css',
            js: 'assets/js',
            images: 'assets/images',
            fonts: 'assets/fonts',
            keys: 'assets/keys',
            rb: rb_path
          }
        end

        def app_asset_paths=(hash)
          @app_asset_paths = hash
        end

        def opal_unaware_gems
          @opal_unaware_gems ||= %w()
        end

        def add_opal_unaware_gems(ary)
          opal_unaware_gems.concat(ary).uniq!
        end

        def css_file_order
          @css_file_order ||= []
        end

        def css_file_order=(ary)
          @css_file_order = ary
        end

        def js_file_order
           @js_file_order ||= []
        end

        def js_file_order=(ary)
           @js_file_order = ary
        end

        # for task logging
        def filter_task_keys
          @filter_task_keys ||= [:password]
        end

        # for task logging
        def filter_task_keys=(ary)
          @filter_task_keys = (ary.to_a.map{|e| e.to_s.to_sym} << [:password]).uniq
        end

        def task_timeout
          @task_timeout ||= 60 # seconds
        end

        def task_timeout=(seconds)
          @task_timeout = seconds
        end

        def min_task_threads
          @min_task_threads ||= 1
        end

        def min_task_threads=(val)
          @min_task_threads = val
        end

        def max_task_threads
          @max_task_threads ||= 16
        end

        def max_task_threads=(val)
          @max_task_threads = val
        end

        def sprockets_memory_cache?
          sprockets_memory_cache_size > 0
        end

        # Defaults to 1000 files
        def sprockets_memory_cache_size
          @sprockets_memory_cache_size ||= 1000
        end

        # Sprockets memory cache is much faster than file cache.
        #
        # Set to zero for no memory cache,
        # otherwise enough to handle all files
        # in your source, gems, assets, etc.
        def sprockets_memory_cache_size=(num_files)
          @sprockets_memory_cache_size = num_files
        end

        def sprockets_logger_level
          @sprockets_logger_level ||= Logger::FATAL
        end

        def sprockets_logger_level=(level)
          @sprockets_logger_level = if level.is_a?(Symbol)
            case level
              when :unknown;  Logger::UNKNOWN
              when :fatal;    Logger::FATAL
              when :error;    Logger::ERROR
              when :warn;     Logger::WARN
              when :info;     Logger::INFO
              when :debug;    Logger::DEBUG
              else
                raise Robe::ConfigError, "invalid sprockets logger level : ##{level}"
            end
          else
            level
          end
        end

      end

    end
  end

  module_function
  def config
    Robe::Server::Config
  end
end

