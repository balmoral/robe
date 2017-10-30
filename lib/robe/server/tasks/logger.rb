# adapted from Volt

require 'robe/server/config'
require 'robe/server/logger'

module Robe
  module Server
    class Tasks
      module Logger

        module_function

        # Task::ArgumentFilterer will recursively walk any arguments to a task and filter any
        # hashes with a filtered key. By default only :password is filtered, but you can add
        # more with Robe::Server::Config.filter_task_keys
        class ArgumentFilterer
          def self.filter(args)
            new(args).run
          end

          def initialize(args)
            @@filter_args ||= Robe.config.filter_task_keys
            @args = args
          end

          def run
            filter_args(@args)
          end

          private

          def filter_args(kwargs)
           (kwargs || {}).map do |k, v|
              if @@filter_args.include?(k.to_sym)
                # filter
                [k, '[FILTERED]']
              else
                # return unfiltered
                [k, filter_args(v)]
              end
            end.to_h # <= convert back to hash
          end
        end

        def log_perform(task_name, run_time, kwargs, error = nil)
          text = compose_message(task_name, run_time, kwargs)
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

        # private

        def compose_message(task_name, run_time, kwargs)
          task_name = colorize(task_name.to_s, :light_blue)
          run_time = colorize(run_time.to_s + 'ms', :green)
          msg = "task #{task_name} in #{run_time}\n"
          if kwargs.size > 0
            arg_str = ArgumentFilterer.filter_args.filter(kwargs).map(&:inspect).join(', ')
            msg += "with args: #{arg_str}\n"
          end
          msg
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

      end
    end
  end
end

