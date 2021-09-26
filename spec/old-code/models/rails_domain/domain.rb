# frozen_string_literal: true

# Domain class holds a list of the entities
module RailsDomain
  class Domain < Dry::Struct
    attribute :models               , Types::Strict::Array.of(RailsDomain::Model)
  end
end