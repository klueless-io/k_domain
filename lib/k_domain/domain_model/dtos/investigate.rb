# frozen_string_literal: true

# Domain class holds a dictionary entry
module KDomain
  module DomainModel
    class Investigate < Dry::Struct
      attribute :issues                 , Types::Strict::Array do
        attribute :step                 , Types::Strict::String
        attribute :location             , Types::Strict::String
        attribute :key                  , Types::Strict::String.optional.default(nil)
        attribute :message              , Types::Strict::String
      end
    end
  end
end
