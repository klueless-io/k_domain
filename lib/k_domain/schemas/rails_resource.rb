# frozen_string_literal: true

# Domain class holds a dictionary entry
module KDomain
  module Schemas
    class RailsResource < Dry::Struct
      attribute :models               , Types::Strict::Array do
        attribute :model_name         , Types::Strict::String
        attribute :table_name         , Types::Strict::String
        attribute :file               , Types::Strict::String
        attribute :exist              , Types::Strict::Bool
        attribute :state              , Types::Strict::String
      end
    end
  end
end
