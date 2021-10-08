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
      attr_reader :model_path
      attr_reader :controller_path
      attr_reader :route_path

      def initialize(db_schema: , target_file: , target_step_file: , model_path:, route_path:, controller_path:)
        @db_schema        = db_schema
        @target_step_file = target_step_file
        @target_file      = target_file
        @model_path       = model_path
        @controller_path  = controller_path
        @route_path      = route_path
      end

      # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
      def call
        valid = true
        valid &&= Step1AttachDbSchema.run(domain_data, db_schema: db_schema, step_file: step_file('1-attach-db-schema'))
        valid &&= Step2AttachModels.run(domain_data, model_path: model_path, step_file: step_file('2-attach-model'))
        valid &&= Step3AttachColumns.run(domain_data, step_file: step_file('3-attach-columns'))
        valid &&= Step4RailsResourceModels.run(domain_data, model_path: model_path, step_file: step_file('4-rails-resource-models'))
        valid &&= Step5RailsResourceRoutes.run(domain_data, route_path: route_path, controller_path: controller_path, step_file: step_file('5-rails-resource-routes'))
        valid &&= Step6RailsStructureModels.run(domain_data, model_path: model_path, step_file: step_file('6-rails-structure-models'))
        valid &&= Step7AttachDictionary.run(domain_data, step_file: step_file('7-attach-dictionary'))

        raise 'DomainModal transform failed' unless valid

        write

        nil
      end
      # rubocop:enable Metrics/AbcSize,Metrics/CyclomaticComplexity

      def step_file(step_name)
        format(target_step_file, step: step_name)
      end

      def write
        FileUtils.mkdir_p(File.dirname(target_file))
        File.write(target_file, JSON.pretty_generate(domain_data))
      end

      def domain_data
        # The initial domain model structure is created here, but populated during the workflows.
        @domain_data ||= {
          domain: {
            models: []
          },
          rails_resource: {
            models: [],
            routes: [],
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
    end
  end
end
