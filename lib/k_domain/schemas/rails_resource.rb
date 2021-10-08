# frozen_string_literal: true

# Domain class holds a dictionary entry
module KDomain
  module Schemas
    # Route related files
    module Types
      include Dry.Types()

      Verb      = Strict::String.enum("", "GET", "PATCH", "POST", "PUT", "DELETE")
    end

    class Route < Dry::Struct
      attribute :name                 , Types::String
      attribute :controller           , Types::String
      attribute :action               , Types::String.optional
      attribute :path                 , Types::String
      attribute :mime_match           , Types::String
      attribute :verbs                , Types.Array(Types::Verb)
      attribute :file                 , Types::String
      attribute :exist                , Types::Bool
    end

    # Model related files
    class Model < Dry::Struct
      attribute :model_name         , Types::String
      attribute :table_name         , Types::String
      attribute :file               , Types::String
      attribute :exist              , Types::Bool
      attribute :state              , Types::String
    end

    class RailsResource < Dry::Struct
      attribute :models, Types.Array(Model)
      attribute :routes, Types.Array(Route)
    end
  end
end
