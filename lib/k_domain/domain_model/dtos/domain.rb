# frozen_string_literal: true

# Domain class holds a list of the entities
module KDomain
  module DomainModel
    class Domain < Dry::Struct
      attribute :models               , Types::Strict::Array.of(KDomain::DomainModel::Model)
      attribute :dictionary           , Types::Strict::Array.of(KDomain::DomainModel::Dictionary)
    end
  end
end
