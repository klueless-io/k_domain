# frozen_string_literal: true

# MainDataset holds the entire domain model including database and ancillary information
module KDomain
  module Schemas
    class MainDataset < Dry::Struct
      attribute :domain           , KDomain::Schemas::Domain
      attribute :database         , KDomain::Schemas::Database
      attribute :dictionary       , KDomain::Schemas::Dictionary
      attribute :rails_resource   , KDomain::Schemas::RailsResource
      attribute :rails_structure  , KDomain::Schemas::RailsStructure
      attribute :investigate      , KDomain::Schemas::Investigate
    end
  end
end
