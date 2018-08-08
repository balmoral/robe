module Robe
  module State
    class Atom
      class State

        def self.attrs
          @attrs ||= []
        end

        def self.attr(*args)
          # puts "#{__FILE__}[#{__LINE__}] #{self.class.name}##{__method__}(#{args})"
          args.each do |attr|
            attr = attr.to_sym
            unless attrs.include?(attr)
              index = attrs.size
              attrs << attr
              # readers
              define_method(attr) do
                @values[index]
              end
              writer = :"#{attr}="
              define_method(writer) do |value|
                unless @mutable
                  raise RuntimeError, "###{writer} only permitted in mutate! block"
                end
                @values[index] = value
              end
            end
          end

          def self.from_hash(hash, mutable = false)
            new(hash, mutable)
          end

          def self.from_array(array, mutable = false)
            new(array, mutable)
          end

          def self.from_json(string, mutable = false)
            hash = JSON.parse(string)
            new(hash, mutable)
          end

          def initialize(seed = nil, mutable = false)
            # trace __FILE__, __LINE__, self, __method__
            @mutable = mutable
            attrs = self.class.attrs
            @values = Array.new(attrs.size)
            if seed.is_a?(Hash)
              seed.each do |key, value|
                key = key.to_sym
                index = attrs.find_index(key)
                unless index
                  raise ArgumentError, "#{key} is not an attribute of #{self.class.name}"
                end
                @values[index] = value
              end
            elsif seed.is_a?(Array)
              unless seed.size == attrs.size
                raise ArgumentError, 'seed array size should be same as number of attributes'
              end
              seed.each_with_index do |value, index|
                @values[index] = value
              end
            elsif seed.nil?
              # nothing to do
            else
              raise ArgumentError, "seed for #{self.class.name} must be an array, hash or nil"
            end
          end

          def clone
            c = super
            c.instance_variable_set(:'@values', @values.clone) # deep_clone
            c
          end

          def dup
            c = super
            c.instance_variable_set(:'@values', @values.dup) # deep_dup
            c
          end

          def mutation_count
            @mutation_count ||= 0
          end

          def mutation_count=(value)
            @mutation_count = value
          end

          def mutable?
            @mutable
          end

          def to_mutable_in_situ
            @mutable = true
          end

          def to_mutable
            m = dup # clone
            m.instance_variable_set(:'@mutable', true)
            m
          end

          def to_immutable
            @mutable = false
            self
          end

          def replicate
            self.class.from_array(to_a, @mutable)
          end

          def to_a
            @values.map(&:dup)
          end

          # TODO: to_h_without_circulars
          def to_h
            result = {}
            self.class.attrs.each_with_index do |attr, index|
              result[attr] = @values[index].dup
            end
            result
          end

          def to_json
            hash = {}
            self.class.attrs.each_with_index do |attr, index|
              hash[attr] = @values[index]
            end
            hash.to_json
          end

        end
      end
    end
  end
end
