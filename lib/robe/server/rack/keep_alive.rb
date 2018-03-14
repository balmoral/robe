module Robe
  module Server
    module Rack
      # For some reason in Rack (or maybe thin), 304 headers close
      # the http connection.  We might need to make this check if keep
      # alive was in the request.
      # Taken from Volt.
      # TODO: confirm this stops drop outs.

      class KeepAlive
        def initialize(app)
          @app = app
        end

        def call(env)
          status, headers, body = @app.call(env)

          # trace __FILE__, __LINE__, self, __method__, " : env['HTTP_CONNECTION'] = #{env['HTTP_CONNECTION']}"
          if status == 304 && env['HTTP_CONNECTION'] && env['HTTP_CONNECTION'].downcase == 'keep-alive'
            headers['Connection'] = 'keep-alive'
          end

          [status, headers, body]
        end
      end
    end
  end
end