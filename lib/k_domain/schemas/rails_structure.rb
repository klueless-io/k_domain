# frozen_string_literal: true

# Domain class holds a dictionary entry
module KDomain
  module Schemas
    class RailsStructure < Dry::Struct
      class DefaultScope < Dry::Struct
        attribute :block?                     , Types::Strict::String
      end

      class BaseType < Dry::Struct
        attribute :name?                      , Types::Strict::String
        attribute :opts?                      , Types::Strict::Hash
        attribute :block?                     , Types::Strict::String.optional.default(nil)
      end

      class Scope < KDomain::Schemas::RailsStructure::BaseType
      end

      class BelongsTo < KDomain::Schemas::RailsStructure::BaseType
      end

      class HasOne < KDomain::Schemas::RailsStructure::BaseType
      end

      class HasMany < KDomain::Schemas::RailsStructure::BaseType
      end

      class HasAndBelongsToMany < KDomain::Schemas::RailsStructure::BaseType
      end

      class Validate < Dry::Struct
        attribute :names?                     , Types::Array.of(Types::Strict::String)
        attribute :opts?                      , Types::Strict::Hash
        attribute :block?                     , Types::Strict::String.optional.default(nil)
      end

      class Validates < KDomain::Schemas::RailsStructure::BaseType
      end

      class Behaviours < Dry::Struct
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
      end

      class Functions < Dry::Struct
      end

      class Model < Dry::Struct
        attribute :model_name                 , Types::Strict::String
        attribute :table_name                 , Types::Strict::String
        attribute :file                       , Types::Strict::String
        attribute :exist                      , Types::Strict::Bool
        attribute :state                      , Types::Strict::String
        attribute :code                       , Types::Strict::String
        attribute :behaviours?                , KDomain::Schemas::RailsStructure::Behaviours
        attribute :functions?                 , KDomain::Schemas::RailsStructure::Functions
      end

      class Controller < Dry::Struct
      end

      attribute :models                       , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Model)
      attribute :controllers                  , Types::Strict::Array.of(KDomain::Schemas::RailsStructure::Controller)
    end
  end
end

# attribute :domain           , KDomain::DomainModel::Domain
