# frozen_string_literal: true

# DomainModel holds the entire domain model including database and ancillary information
module KDomain
  module Schemas
    class DomainModel < Dry::Struct
      attribute :domain         , KDomain::DomainModel::Domain
      attribute :database       , KDomain::Database::Schema
      # attribute :rails_files    , KDomain::RailsFiles::Schema
      attribute :investigate    , KDomain::DomainModel::Investigate
    end
  end
end
