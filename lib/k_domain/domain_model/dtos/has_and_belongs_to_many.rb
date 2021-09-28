# frozen_string_literal: true

module KDomain
  module DomainModel
    class HasAndBelongsToMany
      KEYS = %i[a_lambda autosave code_duplicate].freeze

      attr_accessor :name

      attr_accessor :model_name
      attr_accessor :model_name_plural

      attr_accessor :a_lambda
      attr_accessor :autosave

      attr_accessor :related_entity
      attr_accessor :code_duplicate
    end
  end
end
