# frozen_string_literal: true

module KDomain
  module RawDbSchema
    module Models
      class Index < Dry::Struct
        attribute :name                 , Types::Strict::String
        attribute :fields               , Types::Nominal::Any.optional.default('xxxxx1')
        attribute :using                , Types::Nominal::String
        attribute :order?               , Types::Nominal::Hash
        attribute :where?               , Types::Nominal::Any.optional.default(nil)
        attribute :unique?               , Types::Nominal::Any.optional.default(nil)
      end
    end
  end
end