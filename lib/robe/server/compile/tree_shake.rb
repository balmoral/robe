require 'set'

module Robe
  module Compile
    class TreeShake

      METHOD_DEF = /\w+\.defn\(\w+,"\$([\w\*%]+)"/
      METHOD_CALL = /\.\$(\w+)|\["\$([\w\*%])"\]/
      METHOD_ALIAS = /\w+\.alias\(\w+,"\w+","([\w\*%]+)"/
      METHOD_OBJECT = /\w+\.\$method\("([\w\*%]+)"\)/

      def self.compile(code)
        new(code).result
      end
      
      attr :result

      def initialize(code)
        @result = compile(code)
      end

      private

      def compile(code)
        white_listed_calls = Set.new(%w(new))
        all_filtered = Set.new
        original_stubs = get_stubs(code)
        difference = -1

        while difference != 0
          calls = (
            code.scan(METHOD_CALL) +
            code.scan(METHOD_ALIAS) +
            code.scan(METHOD_OBJECT) +
            []
          )

          calls = calls
            .flatten
            .to_set

          method_defs = code
            .scan(METHOD_DEF)
            .flatten
            .to_set

          filtered = method_defs - (calls + white_listed_calls)
          all_filtered |= filtered

          STDERR.puts(
            method_defs: method_defs.count,
            calls: calls.count,
            white_listed_calls: white_listed_calls.count,
            filtered: filtered.count,
          )

          difference = filtered.count

          position = 0
          while position
            position = code.index(METHOD_DEF, position)
            method_name = $1

            if filtered.include? method_name
              eom = position + 1

              char = nil
              nesting = 0
              until char == ')' && nesting.zero?
                char = code[eom]
                case char
                when '('
                  nesting += 1
                when ')'
                  nesting -= 1
                end

                eom += 1
              end

              if code[eom] == ','
                code[position..eom] = ''
              else
                code[position...eom] = ''
              end
            else
              if position
                position += 1
              else
                break
              end
            end
          end
        end

        code = code.gsub(/,([\)\}])/, '\1')
        code.gsub!(/\.add_stubs\(.*?\)/) do |match|
          methods = match.scan(/\$([^"]+)/).flatten
          stubs = (methods.to_set - all_filtered)
            .map { |stub| "$#{stub}".inspect }
            .join(',')

          ".add_stubs([#{stubs}])"
        end
        new_stubs = get_stubs(code)

        STDERR.puts "Filtered methods:"
        STDERR.puts all_filtered.sort.map { |m| "- #{m}" }
        STDERR.puts "Eliminated #{all_filtered.count} method definitions"
        STDERR.puts "Eliminated %d/%d stubs (%d%%)" % [
          (original_stubs - new_stubs).count,
          original_stubs.count,
          (original_stubs - new_stubs).count.to_f * 100 / original_stubs.count,
        ]

        code
      end

      def get_stubs code
        code
          .scan(/\.add_stubs\(.*\)/)
          .map { |call| call.scan(/"\$?(\w+)"/) }
          .flatten
          .to_set
      end
    end
  end
end



