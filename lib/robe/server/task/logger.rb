# adapted from Volt

require 'robe/server/config'
require 'robe/server/util/logger'
require 'robe/common/db/models/task_log'

module Robe
  module Server
    module Task
      module Logger

        module_function

        IGNORE = %w(ping)

        def performing(name, kwargs)
          return if IGNORE.include?(name)
          # trace __FILE__, __LINE__, self, __method__, "(#{name}, #{kwargs}) name.class=#{name.class}"
          kwargs = (kwargs || {}).symbolize_keys
          kwargs[:password] = '********' if kwargs[:password]
          if Robe.config.log_tasks?
            unless name == 'ping' || (name == 'dbop' && kwargs[:target] == 'task_logs')
              # trace __FILE__, __LINE__, self, __method__, ' saving task to task log'
              Robe::DB::Models::TaskLog.new(time: timestamp, task: name, args: kwargs.to_s).save
              # trace __FILE__, __LINE__, self, __method__, ' saved task to task log'
            end
          end
          text = "#{prefix} : #{colorize('performing', :green)} : #{name_s(name)}#{args_s(kwargs)}"
          Robe.logger.info(text)
        end

        def performed(name, runtime, kwargs, error = nil)
          return if IGNORE.include?(name)
          text = "#{prefix} : #{runtime_s(runtime)} #{colorize('to perform', :green)} : #{name_s(name)}#{args_s(kwargs)}"
          if error
            text += "\n" + colorize(error.to_s, :red)
            if error.is_a?(Exception) && !error.is_a?(Robe::UserError)
              backtrace = error.try(:backtrace)
              if backtrace
                text += "\n" + colorize(error.backtrace.join("\n"), :red)
              end
            end
            Robe.logger.error(text)
          else
            Robe.logger.info(text)
          end
        end

        def failed(name, kwargs, metadata, message)
          text = "#{prefix} : #{colorize('error performing', :red)} : #{name_s(name)}(args: #{args_s(kwargs)}, metadata: #{metadata}) :: #{message}"
          Robe.logger.error(text)
        end

        def timestamp
          Robe.logger.timestamp
        end

        # private

        def runtime_s(t)
          colorize('%0.3fs' % (t.to_f / 1000.0), :green)
        end

        def name_s(name)
          colorize(name.to_s, :light_blue)
        end

        def args_s(kwargs)
          if kwargs && kwargs.size > 0
            args_s = filter_args(kwargs).map(&:inspect).join(', ')
            colorize("(#{args_s})", :light_blue)
          else
            ''
          end
        end

        def prefix
          colorize('Tasks::Logger', :purple)
        end

        def colorize(string, color)
          if STDOUT.tty? && string
            case color
              when :cyan
                "\e[1;34m" + string + "\e[0;37m"
              when :green
                "\e[0;32m" + string + "\e[0;37m"
              when :light_blue
                "\e[1;34m" + string + "\e[0;37m"
              when :purple
                "\e[1;35m" + string + "\e[0;37m"
              when :red
                "\e[1;31m" + string + "\e[0;37m"
            end
          else
            string.to_s
          end
        end

        def filter_args(kwargs)
          kwargs.map do |k, v|
            if filter_args_keys.include?(k.to_sym)
              [k, '[FILTERED]']
            else
              [k, v]
            end
          end.to_h
        end

        def filter_args_keys
          @filter_task_keys ||= Robe.config.filter_task_keys.map(&:to_sym)
        end
      end
    end
  end

  module_function

  def task_logger
    @task_logger ||= Robe::Server::Task::Logger
  end
end

