require 'securerandom'

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

        def source_maps?
          !!@source_maps
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

        def client_app_path
          unless @client_app_path
            fail "config.client_app_path must be set before running app (e.g. 'app_name/client/app.rb')"
          end
          @client_app_path
        end

        def client_app_path=(n)
          @client_app_path = n
        end

        def title
          @title ||= 'Robe App'
        end

        def title=(t)
          @title = t
        end

        def html_literal_head
          # <link rel="shortcut icon" href="//bits.wikimedia.org/favicon/wikipedia.ico">
          @html_literal_head ||= <<-HTML
            <meta charset="utf-8">
            <meta content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0' name='viewport' />
            <meta http-equiv="x-ua-compatible" content="ie=edge"/>    
            <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
            <script src="https://code.jquery.com/jquery-3.2.1.min.js" integrity="sha256-hwg4gsxgFZhOsEEamdOYGBf13FyQuiTwlAQgxVSNgt4=" crossorigin="anonymous"></script>
            <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js" integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa" crossorigin="anonymous"></script>      <link rel="stylesheet" type="text/css" href="https://fonts.googleapis.com/css?family=Roboto:300,400,500,700|Roboto+Slab:400,700|Material+Icons" />
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
          # fonts: 'assets/fonts',
            keys: 'assets/keys',
            rb: 'lib'
          }
        end

        def app_asset_paths=(hash)
          @app_asset_paths = hash
        end

        def opal_unaware_gems
          @opal_unaware_gems ||= %w(
            cx-core
            cx-util
          )
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

        # for task data
        def filter_task_keys
          @filter_keys ||= [:password]
        end

        def filter_task_keys=(ary)
          @filter_keys = (ary.to_a.map{|e| e.to_s.to_sym} << [:password]).uniq
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

      end

    end
  end

  module_function
  def config
    Robe::Server::Config
  end
end

