module KDomain
  module DomainModel
    class RelatedEntity
      # Name of the entity model
      attr_accessor :name
      attr_accessor :name_plural
      attr_accessor :main_key

      attr_accessor :trait1
      attr_accessor :trait2
      attr_accessor :trait3

      def initialize(entity)
        @name        = entity.name
        @name_plural = entity.name_plural
        @main_key    = entity.main_key
        @trait1      = entity.trait1
        @trait2      = entity.trait2
        @trait3      = entity.trait3
      end

      def to_h
        {
          name: name,
          name_plural: name_plural,
          main_key: main_key,
          trait1: trait1,
          trait2: trait2,
          trait3: trait3
        }
      end
    end
  end
end
