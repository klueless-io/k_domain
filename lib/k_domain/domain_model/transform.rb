# frozen_string_literal: true

# Loads the db schema object and works through a series of enrichment steps to
# that builds the domain modal

module KDomain
  module DomainModel
    class Transform
      include KLog::Logging

      attr_reader :db_schema
      attr_reader :target_step_file
      attr_reader :target_file
      attr_reader :erd_path

      def initialize(db_schema: , target_file: , target_step_file: , erd_path:)
        @db_schema        = db_schema
        @target_step_file = target_step_file
        @target_file      = target_file
        @erd_path         = erd_path
      end

      # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      def call
        valid = true
        valid &&= Step1AttachDbSchema.run(domain_data, db_schema: db_schema, step_file: step_file('1-attach-db-schema'))
        valid &&= Step2AttachModels.run(domain_data, erd_path: erd_path, step_file: step_file('2-attach-model'))
        valid &&= Step3AttachColumns.run(domain_data, step_file: step_file('3-attach-columns'))
        valid &&= Step5AttachDictionary.run(domain_data, erd_path: erd_path, step_file: step_file('5-attach-dictionary'))
        valid &&= Step8RailsResourceModels.run(domain_data, erd_path: erd_path, step_file: step_file('8-rails-resource-models'))
        valid &&= Step9RailsStructureModels.run(domain_data, erd_path: erd_path, step_file: step_file('9-rails-structure-models'))

        raise 'DomainModal transform failed' unless valid

        write

        nil
      end
      # rubocop:enable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

      def step_file(step_name)
        target_step_file % { step: step_name }
      end

      def write
        FileUtils.mkdir_p(File.dirname(target_file))
        File.write(target_file, JSON.pretty_generate(domain_data))
      end

      # rubocop:disable Metrics/MethodLength
      def domain_data
        # The initial domain model structure is created here, but populated during the workflows.
        @domain_data ||= {
          domain: {
            models: [],
            erd_files: []
          },
          rails_resource: {
            models: [],
            controllers: []
          },
          rails_structure: {
            models: [],
            controllers: []
          },
          dictionary: {
            items: []
          },
          database: {
            tables: [],
            indexes: [],
            foreign_keys: [],
            meta: {}
          },
          investigate: {
            issues: []
          }
        }
      end

      # rubocop:enable Metrics/MethodLength
    end
  end
end
