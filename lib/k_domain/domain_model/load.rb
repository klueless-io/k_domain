# frozen_string_literal: true

# Annotates the original schema with methods that implement existing method calls
# that are already in the schema so that we can build a hash.
#
# Writes a new annotated schema.rb file with a public method called load that
# builds the hash

module KDomain
  module DomainModel
    class Load
      include KLog::Logging

      attr_reader :source_file
      attr_reader :data

      def initialize(source_file)
        @source_file = source_file
      end

      def call
        json = File.read(source_file)
        @raw_data = KUtil.data.json_parse(json, as: :hash_symbolized)

        # This line is slow on big datasets
        @data = KDomain::Schemas::AllData.new(@raw_data)

        # This line is also slow on big datasets
        enrichment
      end

      def to_h
        return nil unless defined? @raw_data

        @raw_data
      end

      private

      def enrichment
        attach_rails_model_to_domain_model
      end

      def attach_rails_model_to_domain_model
        @data.domain.models.each do |domain_model|
          domain_model.rails_model = @data.rails_structure.find_model(domain_model.name)

          if domain_model.rails_model
            attach_column_relations(domain_model)
          else
            log.error("Rails Model not found for #{domain_model.name}") unless domain_model.rails_model
          end
        end
      end

      def attach_column_relations(domain_model)
        domain_model.columns.each do |column|
          column.relationships = []
          add_column_relations(domain_model.rails_model, column, :belongs_to)
          add_column_relations(domain_model.rails_model, column, :has_one)
          add_column_relations(domain_model.rails_model, column, :has_many)
          add_column_relations(domain_model.rails_model, column, :has_and_belongs_to_many)
        end
      end

      def add_column_relations(rails_model, column, relation_type)
        relations = rails_model.behaviours.send(relation_type)

        return if relations.nil?

        relations = relations.map { |relation| { relation_type: relation_type }.merge(relation.to_h) }
        relations.select { |relation| column[:name] == relation.dig(:opts, :foreign_key) }.each do |relation|
          column.relationships << KDomain::Schemas::Domain::Model::Relationship.new(relation)
        end
      end
    end
  end
end
