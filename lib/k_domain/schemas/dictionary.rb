# frozen_string_literal: true

# Domain class holds a dictionary entry
module KDomain
  module Schemas
    class Dictionary < Dry::Struct
      attribute :items              , Types::Strict::Array do
        attribute :name             , Types::Strict::String
        attribute :type             , Types::Strict::String
        attribute :label            , Types::Strict::String
        attribute :segment          , Types::Strict::String
        attribute :models           , Types::Strict::Array
        attribute :model_count      , Types::Strict::Integer
        attribute :types            , Types::Strict::Array
        attribute :type_count       , Types::Strict::Integer
      end
    end
  end
end
