# frozen_string_literal: true

# DomainModel holds the entire domain model including database and ancillary information
module KDomain
  module DomainModel
    class Schema < Dry::Struct
      attribute :domain         , KDomain::DomainModel::Domain
      attribute :database       , KDomain::RawDbSchema::Schema
      attribute :investigate    , KDomain::DomainModel::Investigate
    end
  end
end
