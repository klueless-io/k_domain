# frozen_string_literal: true

# Domain class holds an investigation entry
module KDomain
  module DomainModel
    class Issue < Dry::Struct
      attribute :step                 , Types::Strict::String
      attribute :location             , Types::Strict::String
      attribute :key                  , Types::Strict::String.optional.default(nil)
      attribute :message              , Types::Strict::String
    end
  end
end
