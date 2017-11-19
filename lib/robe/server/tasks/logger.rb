# adapted from Volt

require 'robe/server/config'
require 'robe/server/logger'

module Robe
  module Server
    class Tasks
      module Logger

        module_function

        def performing(name, kwargs)
          text = "#{prefix} : #{colorize('performing', :green)} : #{name_s(name)}#{args_s(kwargs)}"
          Robe.logger.info(text)
        end

        def performed(name, runtime, kwargs, error = nil)
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

        def timestamp
          colorize(Time.now.strftime('%y/%m/%d %H:%M:%S'), :green)
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
end

