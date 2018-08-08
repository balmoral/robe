require 'stringio'
require 'robe/common/promise'
require 'robe/common/trace'
require 'robe/common/errors'

module Robe
  module DB;
    class Model

      CSV_COMMA_SUB = '~%~' # Robe::Model::CSV_COMMA_SUB
      CSV_NL_SUB    = Robe::Model::CSV_NL_SUB
      CSV_CR_SUB    = Robe::Model::CSV_CR_SUB
      CSV_TAB_SUB   = Robe::Model::CSV_TAB_SUB

      module CSV_IO_Methods

        # Loads all records in the given csv string to the
        # model class's collection/table.
        # Assumes first line in csv is field names.
        # `field_procs` are optional procs for each field to preprocess field value.
        # `csv` may be a single csv with lines separated by "\n" or an array of csv strings.
        def load_csv(csv, field_procs: nil, map_attrs: {}, ignore_attrs: [], ignore_associations: false)
          lines = csv.is_a?(Array) ? csv : csv.split("\n")
          if lines.size > 1
            count = 0
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
            promise_chain(lines) do |line|
              # -1 to split forces trailing empty comma
              # separated field to be returned as empty strings
              # turn empty strings back to nil
              values = line.split(',', -1).map { |s|
                s.present? ? s.gsub(CSV_COMMA_SUB, ',') : nil
              }
              unless values.size == csv_fields.size
                msg = "#{self.name}###{__method__} : values.size #{values.size} != csv_fields.size #{csv_fields.size} => '#{line}'"
                trace __FILE__, __LINE__, self, __method__, " : #{self.class} : error : #{msg}"
                raise Robe::DBError, msg
              end
              hash = {}
              values.each_with_index do |value, index|
                attr = csv_fields[index]
                unless ignore_attrs.include?(attr)
                  proc = field_procs[index]
                  hash[attr] = proc ? proc.call(value) : value
                end
              end
              trace __FILE__, __LINE__, self, __method__, " : #{self.class} : inserting #{hash}"
              instance = self.new(**hash)
              instance.insert(ignore_associations: ignore_associations).then do
                count += 1
              end
            end
          else
            0.to_promise
          end
        end

        # Returns a promise whose value is a csv string
        # dump of all models in the collection/table.
        def to_csv
          self.all.to_promise.then do |all|
            io = StringIO.new
            io << (attrs.join(',') + "\n")
            all.each do |model|
              line = model.to_csv(attrs: attrs, tab_sub: CSV_TAB_SUB, cr_sub: CSV_CR_SUB, nl_sub: CSV_NL_SUB, comma_sub: CSV_COMMA_SUB)  # send(attr).to_s.gsub(',', COMMA_SUB)
              io << (line + "\n")
            end
            io.string.to_promise
          end
        end

      end
    end
  end
end
