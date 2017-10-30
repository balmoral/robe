require 'robe/common/trace'
# mostly cloned from clearwater-bowser - thanks to Jamie Gaskins (@jgaskins)

require 'robe/client/browser/event_target'
require 'robe/common/promise'

module Robe; module Client; module Browser
  class FileList
    include Enumerable

    def initialize(native)
      @native = `#{native} || []`
      @files = length.times.each_with_object([]) { |index, array|
        array[index] = File.new(`#@native[index]`)
      }
    end

    def [](index)
      @files[index]
    end

    def length
      `#@native.length`
    end
    alias size length

    def each(&block)
      @files.each do |file|
        block.call file
      end
    end

    def to_a
      @files.dup # Don't return a value that can mutate our internal state
    end
    alias to_ary to_a

    def to_s
      @files.to_s
    end

    class File
      attr_reader :data

      def initialize(native)
        @native = native
        @data = nil
      end

      def name
        `#@native.name`
      end

      def size
        `#@native.size`
      end

      def type
        `#@native.type`
      end

      def last_modified
        `#@native.lastModifiedDate`
      end

      def read
        promise = Robe::Promise.new
        reader = FileReader.new
        reader.on(:load) do
          result = reader.result

          @data = result
          promise.resolve(result)
        end

        reader.on(:error) do
          promise.reject(reader.result)
        end

        reader.read_as_binary_string(self)

        promise
      end

      class FileReader
        include EventTarget

        def initialize
          @native = `new FileReader()`
        end

        def result
          `#@native.result`
        end

        def read_as_binary_string(file)
          `#@native.readAsBinaryString(file.native)`
        end
      end
    end
  end
end end end
