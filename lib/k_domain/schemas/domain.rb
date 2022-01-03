# frozen_string_literal: true

# Domain class holds a list of the entities
module KDomain
  module Schemas
    class Domain < Dry::Struct
      class Model < Dry::Struct
        class Column < Dry::Struct
          attribute :name                 , Types::Strict::String                         #  "source_account_id"
          attribute :name_plural          , Types::Strict::String                         #  "source_account_ids"
          attribute :type                 , Types::Coercible::Symbol                      #  "integer"
          attribute :precision            , Types::Strict::Integer.optional.default(nil)  #  null
          attribute :scale                , Types::Strict::Integer.optional.default(nil)  #  null
          attribute :default              , Types::Nominal::Any.optional.default(nil)     #  null
          attribute :null                 , Types::Nominal::Any.optional.default(nil)     #  null
          attribute :limit                , Types::Strict::Integer.optional.default(nil)  #  null
          attribute :array                , Types::Strict::Bool.optional.default(nil)     #  null

          # Calculated value
          attribute :structure_type       , Types::Coercible::Symbol

          def db_type
            return @db_type if defined? @db_type

            @db_type = KDomain::Schemas::DB_TYPE[type] || '******'
          end

          def ruby_type
            return @ruby_type if defined? @ruby_type

            @ruby_type = KDomain::Schemas::RUBY_TYPE[type] || '******'
          end

          def csharp_type
            return @csharp_type if defined? @csharp_type

            @csharp_type = KDomain::Schemas::CSHARP_TYPE[type] || '******'
          end
        end

        class Pk < Dry::Struct
          attribute :name               , Types::Strict::String.optional.default(nil)
          attribute :type               , Types::Strict::String.optional.default(nil)
          attribute :exist              , Types::Strict::Bool
        end

        attribute :name                 , Types::Strict::String
        attribute :name_plural          , Types::Strict::String
        attribute :table_name           , Types::Strict::String
        # Model type - :entity, :basic_user, :admin_user, possibly: m2m, agg_root
        attribute :type                 , Types::Strict::Symbol.optional.default(:entity)
        attribute :pk                   , KDomain::Schemas::Domain::Model::Pk
        attribute :columns              , Types::Strict::Array.of(KDomain::Schemas::Domain::Model::Column)
        attribute :file                 , Types::Strict::String.optional.default(nil)

        # Link <KDomain::Schemas::RailsStructure::Model> to the domain model
        attr_accessor :rails_model

        def ruby?
          file && File.exist?(file)
        end

        def pk?
          pk.exist
        end

        # Custom model configurations such as main_key and traits
        def config
          @config ||= KDomain.configuration.find_model(name.to_sym)
        end

        # If filled in, the model has a main field that is useful for rendering and may be used for unique constraint, may also be called display_name
        def main_key
          @main_key ||= config.main_key || KDomain.configuration.fallback_key(columns_data)
        end

        def traits
          config.traits
        end

        def columns_data
          @columns_data ||= columns_for_structure_types(:data)
        end

        def columns_primary
          @columns_primary ||= columns_for_structure_types(:primary_key)
        end

        def columns_foreign
          @columns_foreign ||= columns_for_structure_types(:foreign_key)
        end

        def columns_timestamp
          @columns_data_timestamp ||= columns_for_structure_types(:timestamp)
        end

        def columns_deleted_at
          @columns_data_deleted_at ||= columns_for_structure_types(:deleted_at)
        end

        def columns_virtual
          @columns_virtual ||= columns_for_structure_types(:timestamp, :deleted_at)
        end

        def columns_data_foreign
          @columns_data_foreign ||= columns_for_structure_types(:data, :foreign_key)
        end
        alias rows_fields_and_fk columns_data_foreign

        def columns_data_primary
          @columns_data_primary ||= columns_for_structure_types(:data, :primary_key)
        end
        alias rows_fields_and_pk columns_data_primary

        def columns_data_virtual
          @columns_data_virtual ||= columns_for_structure_types(:data, :timestamp, :deleted_at)
        end
        alias rows_fields_and_virtual columns_data_virtual

        def columns_data_foreign_virtual
          @columns_data_foreign_virtual ||= columns_for_structure_types(:data, :foreign_key, :timestamp, :deleted_at)
        end

        private

        def columns_for_structure_types(*structure_types)
          columns.select { |column| structure_types.include?(column.structure_type) }
        end
      end

      attribute :models , Types::Strict::Array.of(KDomain::Schemas::Domain::Model)
    end
  end
end
