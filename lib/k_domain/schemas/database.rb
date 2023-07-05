# frozen_string_literal: true

# KDomain::Schemas::Domain::Column
# KDomain::Schemas::Domain::Model

module KDomain
  module Schemas
    class Database < Dry::Struct
      class ForeignKey < Dry::Struct
        attribute :left                 , Types::Strict::String
        attribute :right                , Types::Strict::String
        attribute :name?                , Types::Strict::String.optional.default(nil)
        attribute :on_update?           , Types::Strict::String.optional.default(nil)
        attribute :on_delete?           , Types::Strict::String.optional.default(nil)
        attribute :column?              , Types::Strict::String.optional.default(nil)
      end

      class Index < Dry::Struct
        attribute :name                 , Types::Strict::String
        attribute :fields               , Types::Nominal::Any.optional.default(nil)
        attribute :using                , Types::Nominal::String.optional.default(nil)
        attribute :order?               , Types::Nominal::Hash
        attribute :where?               , Types::Nominal::Any.optional.default(nil)
        attribute :unique?              , Types::Nominal::Any.optional.default(nil)
      end

      class View < Dry::Struct
        attribute :name                 , Types::Strict::String
        attribute :materialized         , Types::Strict::Bool
        attribute :sql_definition       , Types::Nominal::String
      end

      class Table < Dry::Struct
        class RailsSchema < Dry::Struct
          attribute :primary_key          , Types::Nominal::Any.optional.default(nil)
          attribute :id                   , Types::Nominal::Any.optional.default(nil)
          attribute :force                , Types::Nominal::Any.optional.default(nil)
        end

        class Column < Dry::Struct
          attribute :name                 , Types::Strict::String
          attribute :type                 , Types::Strict::String
          attribute :precision?           , Types::Strict::Integer.optional.default(nil)
          attribute :scale?               , Types::Strict::Integer.optional.default(nil)
          attribute :default?             , Types::Nominal::Any.optional.default(nil)
          attribute :array?               , Types::Strict::Bool.optional.default(nil)
          attribute :null?                , Types::Strict::Bool.optional.default(nil)
          attribute :limit?               , Types::Strict::Integer.optional.default(nil)
        end

        attribute :name                   , Types::Strict::String
        attribute :primary_key            , Types::Strict::String.optional.default(nil)
        attribute :primary_key_type       , Types::Strict::String.optional.default(nil)
        attribute :id?                    , Types::Nominal::Any.optional.default(nil)
        attribute :columns                , Types::Strict::Array.of(KDomain::Schemas::Database::Table::Column)
        attribute :indexes                , Types::Strict::Array.of(KDomain::Schemas::Database::Index)
        attribute :rails_schema           , KDomain::Schemas::Database::Table::RailsSchema
      end

      class DbInfo < Dry::Struct
        attribute :type                 , Types::Strict::String
        attribute :version              , Types::Nominal::Any.optional.default(nil)
        attribute :extensions           , Types::Strict::Array
      end

      class UniqueKey < Dry::Struct
        attribute :type                 , Types::Strict::String
        attribute :category             , Types::Strict::String.optional
        attribute :key                  , Types::Strict::String
        attribute :keys                 , Types::Strict::Array
      end

      class Meta < Dry::Struct
        attribute :rails                , Types::Strict::Integer
        attribute :db_info              , KDomain::Schemas::Database::DbInfo
        attribute :unique_keys          , Types::Strict::Array.of(KDomain::Schemas::Database::UniqueKey)
      end

      attribute :tables               , Types::Strict::Array.of(KDomain::Schemas::Database::Table)
      attribute :foreign_keys?        , Types::Strict::Array.of(KDomain::Schemas::Database::ForeignKey)
      attribute :indexes?             , Types::Strict::Array.of(KDomain::Schemas::Database::Index)
      attribute :views?               , Types::Strict::Array.of(KDomain::Schemas::Database::View)
      attribute :meta                 , KDomain::Schemas::Database::Meta
    end
  end
end
