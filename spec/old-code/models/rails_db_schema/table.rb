# frozen_string_literal: true

module RailsDbSchema
  class Table < Dry::Struct
    class Meta < Dry::Struct
      attribute :primary_key          , Types::Nominal::Any.optional.default(nil)
      attribute :id                   , Types::Nominal::Any.optional.default(nil)
      attribute :force                , Types::Nominal::Any.optional.default(nil)
    end
  
    attribute :name                 , Types::Strict::String
    attribute :primary_key          , Types::Strict::String.optional.default(nil)
    attribute :primary_key_type     , Types::Strict::String.optional.default(nil)
    attribute :id?                  , Types::Nominal::Any.optional.default(nil) # Types::Strict::String.optional.default(nil)
    attribute :columns              , Types::Strict::Array.of(Column)
    attribute :indexes              , Types::Strict::Array.of(Index)
    attribute :rails_schema         , RailsDbSchema::Table::Meta
  end
end
