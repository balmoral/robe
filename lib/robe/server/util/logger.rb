require 'singleton'
require 'logger'

module Robe
  class Logger < ::Logger
    include Singleton

    def initialize
      super(STDOUT)
      # self.datetime_format = '%H%M%S'
      self.formatter = ->(severity, _time, _progname, msg) {
        "<#{severity[0..0]}:#{timestamp}> #{msg}\n"
      }
    end

    def timestamp
      Time.now.getgm.strftime('%Y%m%d:%H%M%S:%Z')
    end

  end

  module_function

  def logger
    @logger ||= Robe::Logger.instance
  end


end


