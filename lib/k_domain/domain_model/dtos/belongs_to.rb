# frozen_string_literal: true

module KDomain
  module DomainModel
    class BelongsTo
      KEYS = %i[a_lambda polymorphic class_name foreign_key primary_key inverse_of with_deleted code_duplicate].freeze

      attr_accessor :name

      attr_accessor :model_name
      attr_accessor :model_name_plural

      attr_accessor :a_lambda
      attr_accessor :polymorphic
      attr_accessor :class_name
      attr_accessor :foreign_key
      attr_accessor :primary_key
      attr_accessor :inverse_of
      attr_accessor :with_deleted

      attr_accessor :related_entity
      attr_accessor :code_duplicate
    end
  end
end
