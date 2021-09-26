# frozen_string_literal: true

module RailsDbSchema
  class Schema < Dry::Struct
    class Meta < Dry::Struct
      attribute :rails                , Types::Strict::Integer
      attribute :database             , RailsDbSchema::Database
      attribute :unique_keys          , Types::Strict::Array.of(UniqueKey)
    end

    attribute :tables               , Types::Strict::Array.of(Table)
    attribute :foreign_keys?        , Types::Strict::Array.of(ForeignKey)
    attribute :indexes?             , Types::Strict::Array.of(Index)
    attribute :meta                 , RailsDbSchema::Schema::Meta
  end
end
