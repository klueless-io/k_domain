# frozen_string_literal: true

module KDomain
  module RawDbSchema
    module Models
      class Schema < Dry::Struct
        class Meta < Dry::Struct
          attribute :rails                , Types::Strict::Integer
          attribute :database             , KDomain::RawDbSchema::Models::Database
          attribute :unique_keys          , Types::Strict::Array.of(KDomain::RawDbSchema::Models::UniqueKey)
        end

        attribute :tables               , Types::Strict::Array.of(KDomain::RawDbSchema::Models::Table)
        attribute :foreign_keys?        , Types::Strict::Array.of(KDomain::RawDbSchema::Models::ForeignKey)
        attribute :indexes?             , Types::Strict::Array.of(KDomain::RawDbSchema::Models::Index)
        attribute :meta                 , KDomain::RawDbSchema::Models::Schema::Meta
      end
    end
  end
end