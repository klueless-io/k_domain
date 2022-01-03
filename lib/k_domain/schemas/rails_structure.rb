# frozen_string_literal: true

# Domain class holds a dictionary entry
module KDomain
  module Schemas
    class RailsStructure < Dry::Struct
      class DefaultScope < Dry::Struct
        attribute :block?                     , Types::Strict::String
      end

      class NameOptsType < Dry::Struct
        attribute :name?                      , Types::Strict::String | Types::Strict::Bool
        attribute :opts?                      , Types::Strict::Hash
        attribute :block?                     , Types::Strict::String.optional.default(nil)
      end

      class OptsType < Dry::Struct
        attribute :opts?                      , Types::Strict::Hash
      end

      # Model Behaviours
      class Scope                 < KDomain::Schemas::RailsStructure::NameOptsType; end

      class BelongsTo             < KDomain::Schemas::RailsStructure::NameOptsType; end

      class HasOne                < KDomain::Schemas::RailsStructure::NameOptsType; end

      class HasMany               < KDomain::Schemas::RailsStructure::NameOptsType; end

      class HasAndBelongsToMany   < KDomain::Schemas::RailsStructure::NameOptsType; end

      class Validate < Dry::Struct
        attribute :names?                     , Types::Array.of(Types::Strict::String)
        attribute :opts?                      , Types::Strict::Hash
        attribute :block?                     , Types::Strict::String.optional.default(nil)
      end

      class Validates < KDomain::Schemas::RailsStructure::NameOptsType
      end

      class ModelBehaviours < Dry::Struct
        attribute :class_name?                , Types::Strict::String
        attribute :default_scope?             , KDomain::Schemas::RailsStructure::DefaultScope
        attribute :scopes?                    , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Scope)
        attribute :belongs_to?                , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::BelongsTo)
        attribute :has_one?                   , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::HasOne)
        attribute :has_many?                  , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::HasMany)
        attribute :has_and_belongs_to_many?   , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::HasAndBelongsToMany)
        attribute :validate?                  , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Validate)
        attribute :validates?                 , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Validates)
        attribute :attr_accessor?             , Types::Array.of(Types::Strict::String)
        attribute :attr_reader?               , Types::Array.of(Types::Strict::String)
        attribute :attr_writer?               , Types::Array.of(Types::Strict::String)

        # Not sure if I need to do a behaviours by column names
        # def belongs_to_by(foreign_key: )
        # end
        # def has_one_by(foreign_key: )
        # end
        # def has_many_by(foreign_key: )
        # end
        # def has_and_belongs_to_many_to_by(foreign_key: )
        # end
      end

      class Method < Dry::Struct
        attribute :name                       , Types::Strict::String
      end

      class Functions < Dry::Struct
        attribute :class_name?                , Types::Strict::String
        attribute :module_name?               , Types::Strict::String
        attribute :class_full_name?           , Types::Strict::String
        attribute :attr_accessor?             , Types::Array.of(Types::Strict::String)
        attribute :attr_reader?               , Types::Array.of(Types::Strict::String)
        attribute :attr_writer?               , Types::Array.of(Types::Strict::String)
        attribute :klass?                     , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Method)
        attribute :instance_public?           , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Method)
        attribute :instance_private?          , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Method)
      end

      class Model < Dry::Struct
        attribute :model_name                 , Types::Strict::String
        attribute :table_name                 , Types::Strict::String
        attribute :file                       , Types::Strict::String
        attribute :exist                      , Types::Strict::Bool
        attribute :state                      , Types::Strict::String
        attribute :code                       , Types::Strict::String
        attribute :behaviours?                , KDomain::Schemas::RailsStructure::ModelBehaviours
        attribute :functions?                 , KDomain::Schemas::RailsStructure::Functions
      end

      # Controller Behaviours
      class AfterAction                           < KDomain::Schemas::RailsStructure::NameOptsType; end

      class AroundAction                          < KDomain::Schemas::RailsStructure::NameOptsType; end

      class BeforeAction                          < KDomain::Schemas::RailsStructure::NameOptsType; end

      # rubocop:disable Naming/ClassAndModuleCamelCase
      class Prepend_beforeAction                  < KDomain::Schemas::RailsStructure::NameOptsType; end

      class Skip_beforeAction                     < KDomain::Schemas::RailsStructure::NameOptsType; end
      # rubocop:enable Naming/ClassAndModuleCamelCase

      class BeforeFilter                          < KDomain::Schemas::RailsStructure::NameOptsType; end

      class SkipBeforeFilter                      < KDomain::Schemas::RailsStructure::NameOptsType; end

      class Layout                                < KDomain::Schemas::RailsStructure::NameOptsType; end

      class HttpBasicAuthenticateWith             < KDomain::Schemas::RailsStructure::OptsType; end

      class ProtectFromForgery                    < KDomain::Schemas::RailsStructure::OptsType; end

      class RescueFrom < Dry::Struct
        attribute :type                           , Types::Strict::String
      end

      class HelperMethod < Dry::Struct
        attribute :names                          , Types::Strict::Array.of(Types::Strict::String)
      end

      class Helper < Dry::Struct
        attribute :name                           , Types::Strict::String
      end

      class ControllerBehaviours < Dry::Struct
        attribute :class_name?                    , Types::Strict::String
        attribute :after_action?                  , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::AfterAction)
        attribute :around_action?                 , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::AroundAction)
        attribute :before_action?                 , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::BeforeAction)
        attribute :prepend_before_action?         , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Prepend_beforeAction)
        attribute :skip_before_action?            , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Skip_beforeAction)
        attribute :before_filter?                 , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::BeforeFilter)
        attribute :skip_before_filter?            , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::SkipBeforeFilter)
        attribute :layout?                        , KDomain::Schemas::RailsStructure::Layout
        attribute :http_basic_authenticate_with?  , KDomain::Schemas::RailsStructure::OptsType
        attribute :protect_from_forgery?          , KDomain::Schemas::RailsStructure::OptsType

        attribute :rescue_from?                   , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::RescueFrom)
        attribute :helper_method?                 , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::HelperMethod)
        attribute :helper?                        , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Helper)
      end

      class ControllerActions < Dry::Struct
        attribute :route_name?                    , Types::Strict::String
        attribute :action?                        , Types::String.optional
        attribute :uri_path?                      , Types::String
        attribute :mime_match?                    , Types::String
        attribute :verbs?                         , Types.Array(Types::Verb)
      end

      class Controller < Dry::Struct
        attribute :name                       , Types::String
        attribute :path                       , Types::String
        attribute :namespace                  , Types::String
        attribute :file                       , Types::String
        attribute :exist                      , Types::Bool
        attribute :full_file                  , Types::String
        attribute :behaviours?                , KDomain::Schemas::RailsStructure::ControllerBehaviours
        attribute :functions?                 , KDomain::Schemas::RailsStructure::Functions
        attribute :actions?                   , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::ControllerActions)
      end

      attribute :models                       , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Model)
      attribute :controllers                  , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Controller)

      def find_controller(path)
        path = path.to_s
        controllers.find { |controller| controller.path.to_s == path }
      end

      def find_model(name)
        name = name.to_s
        models.find { |model| model.model_name.to_s == name }
      end
    end
  end
end

# attribute :domain           , KDomain::DomainModel::Domain
