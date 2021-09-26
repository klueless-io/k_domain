# frozen_string_literal: true

module KDomain
  module RawDbSchema
    class Schema < Dry::Struct
      class Meta < Dry::Struct
        attribute :rails                , Types::Strict::Integer
        attribute :database             , KDomain::RawDbSchema::Database
        attribute :unique_keys          , Types::Strict::Array.of(KDomain::RawDbSchema::UniqueKey)
      end

      attribute :tables               , Types::Strict::Array.of(KDomain::RawDbSchema::Table)
      attribute :foreign_keys?        , Types::Strict::Array.of(KDomain::RawDbSchema::ForeignKey)
      attribute :indexes?             , Types::Strict::Array.of(KDomain::RawDbSchema::Index)
      attribute :meta                 , KDomain::RawDbSchema::Schema::Meta
    end
  end
end