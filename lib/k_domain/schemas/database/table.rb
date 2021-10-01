# frozen_string_literal: true

module KDomain
  module Database
    class Table < Dry::Struct
      class Meta < Dry::Struct
        attribute :primary_key          , Types::Nominal::Any.optional.default(nil)
        attribute :id                   , Types::Nominal::Any.optional.default(nil)
        attribute :force                , Types::Nominal::Any.optional.default(nil)
      end

      attribute :name                 , Types::Strict::String
      attribute :primary_key          , Types::Strict::String.optional.default(nil)
      attribute :primary_key_type     , Types::Strict::String.optional.default(nil)
      attribute :id?                  , Types::Nominal::Any.optional.default(nil) # Types::Strict::String.optional.default(nil)
      attribute :columns              , Types::Strict::Array.of(KDomain::Database::Column)
      attribute :indexes              , Types::Strict::Array.of(KDomain::Database::Index)
      attribute :rails_schema         , KDomain::Database::Table::Meta
    end
  end
end
