# frozen_string_literal: true

# Domain class holds a dictionary entry
module KDomain
  module DomainModel
    class Investigate < Dry::Struct
      attribute :issues , Types::Strict::Array.of(KDomain::DomainModel::Issue)
    end
  end
end
