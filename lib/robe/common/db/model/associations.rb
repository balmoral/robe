require 'robe/common/db/model/association'

module Robe
  module DB
    class Model
      module Associations
        module ClassMethods

          def types
            %i[belongs_to has_many has_one join]
          end

          def embeddings
            @embeddings ||= if superclass < Robe::DB::Model && superclass.respond_to?(:embeddings)
              superclass.embeddings.dup
            else
              {
                embeds_one: [],
                embeds_many: []
              }
            end
          end

          def embeddings_by_collection
            unless @embeddings_by_collection
              embeddings.each do |_type, type_embeddings|
                type_embeddings.each do | embedding |
                  @embeddings_by_collection[embedding.collection] = embedding
                end
              end
            end
            @embeddings_by_collection
          end

          def add_embedding(**params)
            @embeddings_by_collection = nil
            assoc = Robe::DB::Model::Association.new(self, **params)
            associations[params[:type]] << assoc
          end

          def associations
            # lazy initialize - pull in superclass attrs if relevant
            @associations ||= if superclass < Robe::DB::Model && superclass.respond_to?(:associations)
              superclass.associations.dup
            else
              types.reduce({}) { |hash, type|
                hash[type] = []
                hash
              }
            end
          end

          def associations?
            associations.values.each do |e|
              return true unless e.empty?
            end
            false
          end

          def associations_by_collection
            unless @associations_by_collection
              associations.each do |_type, type_associations|
                type_associations.each do | association |
                  @associations_by_collection[association.collection] = association
                end
              end
            end
            @associations_by_collection
          end

          def add_association(**params)
            @associations_by_collection = nil
            assoc = Robe::DB::Model::Association.new(self, **params)
            type = params[:type]
            associations[type] << assoc
            # trace __FILE__, __LINE__, self, __method__, " associations[#{type}]=#{associations[type]}" if type == :belongs_to
          end

          def has_many_associations
            associations[:has_many]
          end

          def has_one_associations
            associations[:has_one]
          end

          def belongs_to_associations
            associations[:belongs_to]
          end

          def join_associations
            associations[:join]
          end

          # Returns a belongs_to association whose associated collection is `collection`
          # or nil if none defined.
          def belongs_to_association(collection)
            belongs_to_associations.find { |a| a.collection == collection }
          end

          # e.g. class Ingredient; belongs_to: :recipe end
          #   collection = :recipes
          #   foreign_key = :_id
          #   local_key = :recipe_id
          def belongs_to(what, **options)
            what = what.to_s
            if what.plural?
              raise NameError, "belongs_to takes a singular association name (not '#{what}')"
            end
            add_association(
              type:         __method__,
              collection:   options.fetch(:collection, what).to_s.pluralize,
              foreign_key:  options.fetch(:foreign_key, :_id),
              local_key:    options.fetch(:local_key, :"#{what}_id"),
              local_attr:   what.to_sym
            )
          end

          # e.g.
          #   class Recipe
          #     has_many: :ingredients, owner: true
          #   end
          #   class Group
          #     has_many: :users, owner: false
          #   end
          # has_many creates a method on the Robe::DB::Model that returns a promise to get the associated models.
          # If `owner` is true then the associated models will be deleted if the owner is deleted.
          # `owner` defaults to false if not specified.
          def has_many(what, **options)
            what = what.to_s
            unless what.plural?
              raise NameError, "`has_many` expects a plural association name (not '#{what}')"
            end
            add_association(
              type:         __method__,
              collection:   options.fetch(:collection, what).to_s.pluralize,
              foreign_key:  options.fetch(:foreign_key, :"#{self.collection_name.singularize}_id"),
              local_key:    options.fetch(:local_key, :_id),
              local_attr:   what.to_sym,
              owner:        !!options[:owner]

            )
          end

          # e.g.
          #   class Product
          #     has_one: :recipe, own: true
          #   end
          # has_one creates a method on the Robe::DB::Model that returns a promise to get the associated model.
          # If `owner` is true then the associated model will be deleted if the owner is deleted.
          # `owner` defaults to false if not specified.
          def has_one(what, **options)
            what = what.to_s
            if what.plural?
              raise NameError, "`has_one` takes a singular association name (not '#{what}')"
            end
            add_association(
              type:         __method__,
              collection:   options.fetch(:collection, what).to_s.pluralize,
              foreign_key:  options.fetch(:foreign_key, :"#{self.collection_name.singularize}_id"),
              local_key:    options.fetch(:local_key, :_id),
              local_attr:   what.to_sym,
              owner:        !!options[:owner]
            )
          end

          # e.g.
          #   class Ingredient
          #     join: :product
          #   end
          #
          # #joins creates a method on the Robe::DB::Model that returns a promise to get the associated model.
          def join(what, **options)
            what = what.to_s
            if what.plural?
              raise NameError, "`joins` takes a singular association name (not '#{what}')"
            end
            add_association(
              type:         __method__,
              collection:   options.fetch(:collection, what).to_s.pluralize,
              foreign_key:  options.fetch(:foreign_key, :_id),
              local_key:    options.fetch(:local_key, :"#{what}_id"),
              local_attr:   what.to_sym,
              owner:        false
            )
          end

          # e.g.
          #   class Recipe
          #     embed_many: :ingredients
          #   end
          #   class Group
          #     has_many: :users, owner: false
          #   end
          # embed_many creates a method on the Robe::DB::Model that returns the embedded models (no promise).
          def embed_many(what)
            fail 'embedding not implemented yet'
            what = what.to_s
            unless what.plural?
              raise NameError, "embeds_many expects a plural association name (not '#{what}')"
            end
            add_embedding(
              type:         __method__,
              local_attr:   what.to_sym
            )
          end

          # e.g.
          #   class Product
          #     embed_one: :recipe
          #   end
          # embeds_many creates a method on the Robe::DB::Model that returns the embedded models (no promise).
          def embed_one(_what)
            fail 'embedding not implemented yet'
            what = _what.to_s
            if what.plural?
              raise NameError, "embed_one takes a singular association name (not '#{what}')"
            end
            add_embedding(
              type:         __method__,
              local_attr:   what.to_sym,
            )
          end

          def find_belongs_to(foreign_class)
            belongs_to_associations.find { |a|
              a.collection == foreign_class.collection_name
            }
          end

        end

        def self.included(base)
          base.extend(ClassMethods)
        end

      end
    end
  end
end
