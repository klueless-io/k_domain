# frozen_string_literal: true

# Loads the db schema object and works through a series of enrichment steps to
# that builds the domain modal

module KDomain
  module DomainModel
    class Transform
      include KLog::Logging

      attr_reader :db_schema
      attr_reader :source_file
    
      def initialize(db_schema)#, source_file)#, target_file)
        @db_schema = db_schema
        # @source_file = source_file
        # @template_file = 'lib/k_domain/raw_db_schema/template.rb'
      end
 
      def call(*steps)
        all = steps.empty?

        valid = true
        valid = valid && Step1AttachDbSchema.run(domain_data, db_schema: db_schema) if all || steps.include?(:attach_database)
        valid = valid && Step2AttachModels.run(domain_data)                         if all || steps.include?(:attach_models)

        rails 'DomainModal transform failed' unless valid

        nil
      end

      def domain_data
        # The initial domain model structure is created here, but populated during the workflows.
        @domain_data ||= {
          domain: {
            models: [],
            erd_files: [],
            dictionary: [],
          },
          database: {
          },
          investigate: {
            investigations: [] # things to investigate
          }
        }
      end
    end
  end
end
