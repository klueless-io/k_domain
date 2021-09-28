module KDomain
  module DomainModel
    class HasMany
      KEYS = %i[a_lambda as dependent through class_name inverse_of primary_key foreign_key source code_duplicate]

      attr_accessor :name

      attr_accessor :model_name
      attr_accessor :model_name_plural

      attr_accessor :a_lambda
      attr_accessor :as
      attr_accessor :dependent
      attr_accessor :through
      attr_accessor :class_name
      attr_accessor :inverse_of
      attr_accessor :primary_key
      attr_accessor :foreign_key
      attr_accessor :source

      attr_accessor :related_entity
      attr_accessor :code_duplicate
    end
  end
end
