module Robe
  module Sockets

    # TODO: determine ws or wss get from server/document - see Volt for how
    # TODO: allow apps to override or configure ?
    # TODO: in production this should be wss ?
    def url
      if RUBY_PLATFORM == 'opal'
        unless @sockets_url
          # The websocket url can be overridden by config.public.websocket_url
          url = "#{`document.location.host`}/socket"
          if url !~ /^wss?[:]\/\//
            if url !~ /^[:]\/\//
              # Add :// to the front
              url = "://#{url}"
            end
            ws_proto = (`document.location.protocol` == 'https:') ? 'wss' : 'ws'
            # Add wss? to the front
            url = "#{ws_proto}#{url}"
          end
          trace __FILE__, __LINE__, self, __method__, " sockets url = #{url}"
          @sockets_url = url
        end
        @sockets_url
      else
        nil # 'ws://localhost:9292/socket'
      end
    end

    def task_channel
      :tasks
    end

    def db_channel
      :db
    end

    def pubsub_channel
      :pubsub
    end

    def chat_channel
      :chat
    end

    def channels
      @channels ||= [
        task_channel,
        db_channel,
        pubsub_channel,
        chat_channel
      ]
    end
  end
end






