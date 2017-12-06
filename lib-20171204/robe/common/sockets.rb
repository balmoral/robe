module Robe
  module Sockets

    def task_channel
      :tasks
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
        pubsub_channel,
        chat_channel
      ]
    end
  end
end






