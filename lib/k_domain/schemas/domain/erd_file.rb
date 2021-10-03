# frozen_string_literal: true

# Domain class holds a list of the entities
module KDomain
  module DomainModel
    # rubocop:disable Metrics/BlockLength
    class ErdFile < Dry::Struct
      attribute :name                         , Types::Strict::String
      attribute :name_plural                  , Types::Strict::String
      attribute :dsl_file                     , Types::Strict::String

      attribute? :source                      , Dry::Struct.optional.default(nil) do
        attribute :ruby                       , Types::Strict::String
        attribute :public                     , Types::Strict::String.optional.default(nil)
        attribute :private                    , Types::Strict::String.optional.default(nil)

        attribute? :all_methods               , Dry::Struct.optional.default(nil) do
          attribute? :klass                   , Types::Strict::Array do
            attribute :name                   , Types::Strict::String
            attribute :scope                  , Types::Strict::String # .optional.default(nil)
            attribute :class_method           , Types::Strict::Bool
            attribute :arguments              , Types::Strict::String
          end
          attribute? :instance                , Types::Strict::Array do
            attribute :name                   , Types::Strict::String
            attribute :scope                  , Types::Strict::String # .optional.default(nil)
            attribute :class_method           , Types::Strict::Bool
            attribute :arguments              , Types::Strict::String
          end
          attribute? :instance_public         , Types::Strict::Array do
            attribute :name                   , Types::Strict::String
            attribute :scope                  , Types::Strict::String # .optional.default(nil)
            attribute :class_method           , Types::Strict::Bool
            attribute :arguments              , Types::Strict::String
          end
          attribute? :instance_private        , Types::Strict::Array do
            attribute :name                   , Types::Strict::String
            attribute :scope                  , Types::Strict::String # .optional.default(nil)
            attribute :class_method           , Types::Strict::Bool
            attribute :arguments              , Types::Strict::String
          end
        end
      end
      attribute? :dsl                       , Dry::Struct.optional.default(nil) do
        attribute :default_scope            , Types::Strict::String.optional.default(nil)

        attribute? :scopes                  , Types::Strict::Array do
          attribute :name                   , Types::Strict::String
          attribute :scope                  , Types::Strict::String # .optional.default(nil)
        end
        attribute? :belongs_to              , Types::Strict::Array do
          attribute :name                   , Types::Strict::String
          attribute :options                , Types::Strict::Hash.optional.default({}.freeze)
          attribute :raw_options            , Types::Strict::String
        end
        attribute? :has_one                 , Types::Strict::Array do
          attribute :name                   , Types::Strict::String
          attribute :options                , Types::Strict::Hash.optional.default({}.freeze)
          attribute :raw_options            , Types::Strict::String
        end
        attribute? :has_many                , Types::Strict::Array do
          attribute :name                   , Types::Strict::String
          attribute :options                , Types::Strict::Hash.optional.default({}.freeze)
          attribute :raw_options            , Types::Strict::String
        end
        attribute? :has_and_belongs_to_many , Types::Strict::Array do
          attribute :name                   , Types::Strict::String
          attribute :options                , Types::Strict::Hash.optional.default({}.freeze)
          attribute :raw_options            , Types::Strict::String
        end
        attribute? :validate_on             , Types::Strict::Array do
          attribute :line                   , Types::Strict::String
        end
        attribute? :validates_on            , Types::Strict::Array do
          attribute :name                   , Types::Strict::String
          attribute :raw_options            , Types::Strict::String
        end
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
