# frozen_string_literal: true

module KDomain
  module Database
    class ForeignKey < Dry::Struct
      attribute :left                 , Types::Strict::String
      attribute :right                , Types::Strict::String
      attribute :name?                , Types::Strict::String.optional.default(nil)
      attribute :on_update?           , Types::Strict::String.optional.default(nil)
      attribute :on_delete?           , Types::Strict::String.optional.default(nil)
      attribute :column?              , Types::Strict::String.optional.default(nil)
    end
  end
end
