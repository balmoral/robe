require 'robe/common/state/atom'
require 'robe/client/server/tasks'
require 'robe/client/util/logger'

module Robe; module Client; module Server
  class Task < Robe::Atom

    # Create a new task and perform it.
    # - auth should be true if user id and signature are required.
    # - args if required should be a hash
    # - if block is given it will be called when the task
    #   has a status of :complete or :failed, with the task
    #   as the argument to the block
    # - if no block is given the caller may choose to observe
    #   or subscribe to changes in the task state, including status.
    #
    # Returns the created task, after perform has been called.
    # As task execution is async the status of the task may be
    # :waiting, :complete of :failed.
    def self.perform(name, auth: nil, args: nil, &block)
      task = new(name, auth: auth, args: args)
      task.perform(&block)
      task
    end

    # read only's
    attr_reader :name   # of task
    attr_reader :auth   # whether to include meta_data[:user][:id] & meta_data[:user][:signature] in request

    # mutated as task is performed
    attr args         # for task
    attr status       # %i[ready waiting complete failed]
    attr response     # the response if status == :complete, otherwise nil
    attr error        # the error if status == :failed, otherwise nil
    attr start_time   # time that perform was called was made as Time
    attr finish_time  # time that response was received as Time if status == :complete or :failed

    def initialize(name:, auth: nil, args: nil)
      @name = name
      @auth = auth.nil? ? false : auth
      super(status: ready, args: args.to_h)
    end

    %i[ready waiting complete failed].each do |which|
      define_method(:"#{which}?") do
        status == which
      end
    end

    def response?
      !!response
    end

    def error?
      !!error
    end
    
    # Returns nil if no request or no response,
    # otherwise finish time - start time as a Float.
    def duration
      finish_time - start_time if start_time && finish_time
    end
    
    # Perform the task with new or additional arguments.
    # If block is given it will be called when the task
    # has a status of :complete or :failed, with the task
    # as the argument to the block.
    def perform(**args, &block)
      # trace __FILE__, __LINE__, self, __method__, "(#{task_name}, {kwargs})"
      mutate!(
        status: :waiting,
        args: args.merge(args),
        response: nil,
        error: nil,
        start_time: Time.new,
        finish_time: nil,
      )
      subscription = if block
        subscribe(where: "#{__FILE__}[#{__LINE__}]") do
          block.call(self)
        end
      end
      Tasks.perform(name, auth: auth, **args).then do |response|
        mutate!(
          status: :complete,
          response: response,
          finish_time: Time.now
        )
      end.fail do |error|
        mutate!(
          status: :failed,
          error: error,
          finish_time: Time.now
        )
      end.always do
        unsubscribe(subscription) if subscription
      end
    end

  end
end end end


