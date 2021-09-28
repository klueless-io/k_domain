# frozen_string_literal: true

module KDomain
  module RawDbSchema
    class Column < Dry::Struct
      attribute :name                 , Types::Strict::String
      attribute :type                 , Types::Strict::String
      attribute :precision?           , Types::Strict::Integer.optional.default(nil)
      attribute :scale?               , Types::Strict::Integer.optional.default(nil)
      attribute :default?             , Types::Nominal::Any.optional.default(nil) # Types::Strict::Bool.optional.default(nil) | Types::Strict::Integer.optional.default(nil)
      attribute :array?               , Types::Strict::Bool.optional.default(nil)
      attribute :null?                , Types::Strict::Bool.optional.default(nil)
      attribute :limit?               , Types::Strict::Integer.optional.default(nil)
    end
  end
end
