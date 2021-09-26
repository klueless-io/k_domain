# frozen_string_literal: true

module RailsDbSchema
  class Database < Dry::Struct
    attribute :type                 , Types::Strict::String
    attribute :version              , Types::Nominal::Any.optional.default(nil)
    attribute :extensions           , Types::Strict::Array
  end
end