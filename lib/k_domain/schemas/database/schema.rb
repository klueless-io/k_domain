# frozen_string_literal: true

module KDomain
  module Database
    class Schema < Dry::Struct
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
        attribute :db_info              , KDomain::Database::Schema::DbInfo
        attribute :unique_keys          , Types::Strict::Array.of(KDomain::Database::Schema::UniqueKey)
      end

      attribute :tables               , Types::Strict::Array.of(KDomain::Database::Table)
      attribute :foreign_keys?        , Types::Strict::Array.of(KDomain::Database::ForeignKey)
      attribute :indexes?             , Types::Strict::Array.of(KDomain::Database::Index)
      attribute :meta                 , KDomain::Database::Schema::Meta
    end
  end
end
