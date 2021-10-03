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
        valid &&= step1
        valid &&= step2
        valid &&= step3
        valid &&= step4
        valid &&= step5
        valid &&= step8
        valid &&= step9

        raise 'DomainModal transform failed' unless valid

        write

        nil
      end
      # rubocop:enable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

      def step1
        Step1AttachDbSchema.run(domain_data, db_schema: db_schema)
        write(step: '1-attach-db-schema')
      end

      def step2
        Step2AttachModels.run(domain_data, erd_path: erd_path)
        write(step: '2-attach-model')
      end

      def step3
        Step3AttachColumns.run(domain_data)
        write(step: '3-attach-columns')
      end

      def step4
        Step4AttachErdFiles.run(domain_data, erd_path: erd_path)
        write(step: '4-attach-erd-files')
      end

      def step5
        Step5AttachDictionary.run(domain_data, erd_path: erd_path)
        write(step: '5-attach-dictionary')
      end

      def step8
        Step8RailsResourceModels.run(domain_data, erd_path: erd_path)
        write(step: '8-rails-resource-models')
      end

      def step9
        Step9RailsStructureModels.run(domain_data, erd_path: erd_path)
        write(step: '8-rails-structure-models')
      end

      def write(step: nil)
        file = if step.nil?
                 target_file
               else
                 format(target_step_file, step: step)
               end
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, JSON.pretty_generate(domain_data))
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
