# frozen_string_literal: true

# Domain class holds a list of the entities
module RailsDomain
  class DomainModel < Dry::Struct
    attribute :domain         , RailsDomain::Domain
    # attribute :database     :::: Not needed
    # attribute :investigate  :::: Not needed
  end
end
