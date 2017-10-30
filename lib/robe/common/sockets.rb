module Robe
  module Sockets

    # TODO: determine ws or wss get from server/document - see Volt for how
    # TODO: allow apps to override or configure ?
    # TODO: in production this should be wss ?
    def url
      'ws://localhost:9292/socket'
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






