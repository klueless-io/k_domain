# frozen_string_literal: true

module KDomain
  module Database
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

      attribute :name                 , Types::Strict::String
      attribute :primary_key          , Types::Strict::String.optional.default(nil)
      attribute :primary_key_type     , Types::Strict::String.optional.default(nil)
      attribute :id?                  , Types::Nominal::Any.optional.default(nil)
      attribute :columns              , Types::Strict::Array.of(KDomain::Database::Table::Column)
      attribute :indexes              , Types::Strict::Array.of(KDomain::Database::Index) # May want to have a Table::Index, but for now this is a shared scheam
      attribute :rails_schema         , KDomain::Database::Table::RailsSchema
    end
  end
end
