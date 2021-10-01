# frozen_string_literal: true

module KDomain
  module Database
    class Schema < Dry::Struct
      class Meta < Dry::Struct
        attribute :rails                , Types::Strict::Integer
        attribute :database             , KDomain::Database::Database
        attribute :unique_keys          , Types::Strict::Array.of(KDomain::Database::UniqueKey)
      end

      attribute :tables               , Types::Strict::Array.of(KDomain::Database::Table)
      attribute :foreign_keys?        , Types::Strict::Array.of(KDomain::Database::ForeignKey)
      attribute :indexes?             , Types::Strict::Array.of(KDomain::Database::Index)
      attribute :meta                 , KDomain::Database::Schema::Meta
    end
  end
end
