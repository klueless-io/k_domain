# frozen_string_literal: true

# DomainModel holds the entire domain model including database and ancillary information
module KDomain
  module Schemas
    class DomainModel < Dry::Struct
      attribute :domain         , KDomain::DomainModel::Domain
      attribute :database       , KDomain::Database::Schema
      attribute :rails_resource , KDomain::Schemas::RailsResource
      attribute :investigate    , KDomain::Schemas::Investigate
    end
  end
end
