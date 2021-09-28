# frozen_string_literal: true

# Domain class holds a list of the entities
module KDomain
  module DomainModel
    class ErdFileSource < Dry::Struct
      attribute :ruby                 , Types::Strict::String
      attribute :public               , Types::Strict::String
      attribute :private              , Types::Strict::String
    end
  end
end
