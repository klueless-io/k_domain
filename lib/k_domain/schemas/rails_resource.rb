# frozen_string_literal: true

# Domain class holds a dictionary entry
module KDomain
  module Schemas
    # Route related files
    module Types
      include Dry.Types()

      Verb      = Strict::String.enum('', 'GET', 'PATCH', 'POST', 'PUT', 'DELETE')
    end

    class Route < Dry::Struct
      attribute :name                 , Types::String
      attribute :controller_name      , Types::String
      attribute :controller_path      , Types::String
      attribute :controller_namespace , Types::String
      attribute :controller_file      , Types::String
      attribute :controller_exist     , Types::Bool
      attribute :action               , Types::String.optional
      attribute :uri_path             , Types::String
      attribute :mime_match           , Types::String
      attribute :verbs                , Types.Array(Types::Verb)
      attribute :file                 , Types::String
      attribute :exist                , Types::Bool
      attribute :duplicate_verb       , Types::Bool
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

      # def find_route(name)
      #   name = name.to_s
      #   routes.find { |route| route.name.to_s == name }
      # end

      def find_model(name)
        name = name.to_s
        models.find { |model| model.model_name.to_s == name }
      end
    end
  end
end
