# frozen_string_literal: true

# Rails model represents information that is found the model.rb class in the rails project
module KDomain
  module DomainModel
    class DomainStatistics
      attr_reader :domain
      attr_accessor :column_counts
      attr_accessor :code_counts
      attr_accessor :code_dsl_counts
      attr_accessor :data_counts
      attr_accessor :issues

      def initialize(domain)
        @domain = domain
        # @column_counts = OpenStruct.new(meta[:column_counts])
        # @code_counts = OpenStruct.new(meta[:code_counts])
        # @code_dsl_counts = OpenStruct.new(meta[:code_dsl_counts])
        # @data_counts = OpenStruct.new(meta[:data_counts])
        # @issues = meta[:issues]
      end

      def print
        log.warn('Statistics ::')
        log.kv('Database Entities', domain.entities.length)
      end
    end
  end
end
