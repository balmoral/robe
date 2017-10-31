module Robe
  module Sockets

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






