require 'singleton'
require 'logger'

module Robe
  class Logger < ::Logger
    include Singleton

    def initialize
      super(STDOUT)
      # self.datetime_format = '%H%M%S'
      self.formatter = proc do |severity, time, progname, msg |
        "<#{severity[0..0]}:#{time.strftime('%y%m%d:%H%M%S')}> #{msg}\n"
      end
    end

  end

  module_function

  def logger
    @logger ||= Robe::Logger.instance
  end

end


