# frozen_string_literal: true

module KDomain
  module Queries
    class BaseQuery
      attr_reader :domain_model

      def initialize(domain_model)
        @domain_model = domain_model
      end
    end
  end
end
