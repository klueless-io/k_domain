# frozen_string_literal: true

# Domain class holds a list of the entities
module KDomain
  module DomainModel
    class Model < Dry::Struct
      class Pk < Dry::Struct
        attribute :name               , Types::Strict::String.optional.default(nil)
        attribute :type               , Types::Strict::String.optional.default(nil)
        attribute :exist              , Types::Strict::Bool
      end

      class ErdLocation < Dry::Struct
        attribute :file               , Types::Strict::String
        attribute :exist              , Types::Strict::Bool
        attribute :state              , Types::Strict::Array
      end

      attribute :name                 , Types::Strict::String
      attribute :name_plural          , Types::Strict::String
      attribute :table_name           , Types::Strict::String
      # Model type - :entity, :basic_user, :admin_user, possibly: m2m, agg_root
      attribute :type                 , Types::Strict::Symbol.optional.default(:entity)
      attribute :pk                   , KDomain::DomainModel::Model::Pk
      attribute :erd_location         , KDomain::DomainModel::Model::ErdLocation
      attribute :columns              , Types::Strict::Array.of(KDomain::DomainModel::Column)

      def has_ruby?
        location.exist
      end

      def has_pk?
        pk.exist
      end

      # If filled in, the model has a main field that is useful for rendering and may be used for unique constraint, may also be called display_name
      def main_key
        @main_key ||= MainKey.lookup(name, columns_data)
      end

      def traits
        @traits ||= Traits.lookup(name)
      end

      # def where()
      # end

      # def columns_where()
      # end

      # Column filters

      def columns_data
        @columns_data ||= columns_for_structure_types(:data)
      end

      # def columns_data_optional
      #   @columns_data_optional ||= columns_for_structure_types(:data).select { |c| true }
      # end

      # def columns_data_required
      #   @columns_data_required ||= columns_for_structure_types(:data).select { |c| false }
      # end

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
  end
end
