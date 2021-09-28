# frozen_string_literal: true

module KDomain
  module DomainModel
    class ForeignKey
      KEYS = %i[column name on_update on_delete].freeze

      attr_accessor :left
      attr_accessor :right

      attr_accessor :column
      attr_accessor :name
      attr_accessor :on_update
      attr_accessor :on_delete
    end
  end
end
