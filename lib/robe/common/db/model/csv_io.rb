require 'stringio'
require 'robe/common/promise'
require 'robe/common/trace'
require 'robe/common/errors'

module Robe; module DB;
  class Model
    module CSV_IO_Methods

      COMMA_SUB = '~%~'
      
      # Loads all records in the given csv string to the
      # model class's collection/table.
      # Assumes first line in csv is field names.
      # `field_procs` are optional procs for each field to preprocess field value.
      # `csv` may be a single csv with lines separated by "\n" or an array of csv strings.
      def load_csv(csv, field_procs: nil, map_attrs: {}, ignore_attrs: [], ignore_associations: false)
        lines = csv.is_a?(Array) ? csv : csv.split("\n")
        promises = []
        if lines.size > 1
          attrs = self.attrs
          csv_fields = lines[0].split(',').map(&:to_sym)
          csv_fields = csv_fields.map{|f| f == :id ? :_id : f}
          csv_fields = csv_fields.map{|f| map_attrs[f] || f}
          csv_fields.each do |field|
            unless ignore_attrs.include?(field)
              unless attrs.include?(field)
                raise Robe::DBError, "#{self.name}###{__method__} : csv field '#{field}' is not an attribute."
              end
            end
          end
          field_procs = csv_fields.map { |name|
            field_procs.nil? ? nil : field_procs[name]
          }
          lines = lines[1..-1]
          lines.each do |line|
            # -1 to split forces trailing empty comma
            # separated field to be returned as empty strings
            # turn empty strings back to nil
            values = line.split(',', -1).map { |s|
              s.present? ? s.gsub(COMMA_SUB, ',') : nil
            }
            unless values.size == csv_fields.size
              raise Robe::DBError, "#{self.name}###{__method__} : values.size #{values.size} != field_names.size #{attrs.size} => '#{line}'"
            end
            hash = {}
            values.each_with_index do |value, index|
              attr = csv_fields[index]
              unless ignore_attrs.include?(attr)
                proc = field_procs[index]
                hash[attr] = proc ? proc.call(value) : value
              end
            end
            instance = self.new(**hash)
            promises << instance.insert(ignore_associations: ignore_associations)
          end
        end
        promises.to_promise_when.then do |r|
          trace __FILE__, __LINE__, self, __method__, " r.size=#{r.size}"
          r
        end
      end

      # Returns a promise whose value is a csv string
      # dump of all models in the collection/table.
      def to_csv
        self.all.to_promise.then do |all|
          io = StringIO.new
          io << (attrs.join(',') + "\n")
          all.each do |model|
            values = attrs.map{ |attr|
              model.send(attr).to_s.value.gsub(',', COMMA_SUB)
            }
            io << (values.join(',') + "\n")
          end
          io.string.to_promise
        end
      end

    end
  end
end end
