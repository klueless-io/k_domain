# frozen_string_literal: true

module KDomain
  module Database
    # Keep a track of unique keys that appear in the data structures
    # so that we can track what new attributes to add to the models
    class UniqueKey < Dry::Struct
      attribute :type                 , Types::Strict::String
      attribute :category             , Types::Strict::String.optional
      attribute :key                  , Types::Strict::String
      attribute :keys                 , Types::Strict::Array
    end
  end
end
