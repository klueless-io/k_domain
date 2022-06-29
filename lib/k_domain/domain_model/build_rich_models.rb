# frozen_string_literal: true

# Loads the db schema object and works through a series of enrichment steps to
# that builds the domain modal

module KDomain
  module DomainModel
    class BuildRichModels
      include KLog::Logging

      attr_reader :db_schema
      attr_reader :target_folder
      attr_reader :query

      def initialize(domain_model:, target_folder:)
        @domain_model   = domain_model
        @target_folder  = target_folder
        @query          = KDomain::Queries::DomainModelQuery.new(domain_model)
      end

      def call
        FileUtils.mkdir_p(target_folder)

        export_domain_models(query.all) # .take(3))
      end

      def export_domain_models(models)
        puts 'export domain models'
        models.each do |model|
          # write a single dot to the console in the color red
          print "\e[31m.\e[0m"

          json = JSON.pretty_generate(build_rich_model(model))
          target_file = File.join(target_folder, "#{model.name}.json")
          File.write(target_file, json)
        end
      end

      def build_rich_model(model)
        {
          name: model.name,
          name_plural: model.name_plural,
          table_name: model.table_name,
          type: model.type,
          pk: model.pk.to_h,
          file: model.file,
          exist: model.ruby?,
          create_update_timestamp: model.create_update_timestamp?,
          main_key: model.main_key,
          traits: model.traits,
          column_names: {
            all: model.columns.map(&:name),
            data: model.columns_data.map(&:name),
            primary: model.columns_primary.map(&:name),
            foreign_key: model.columns_foreign_key.map(&:name),
            foreign_type: model.columns_foreign_type.map(&:name),
            timestamp: model.columns_timestamp.map(&:name),
            deleted_at: model.columns_deleted_at.map(&:name),
            virtual: model.columns_virtual.map(&:name),
            data_foreign: model.columns_data_foreign.map(&:name),
            data_primary: model.columns_data_primary.map(&:name),
            data_virtual: model.columns_data_virtual.map(&:name),
            data_foreign_virtual: model.columns_data_foreign_virtual.map(&:name)
          },
          columns: {
            all: model.columns.map(&:to_h),
            data: model.columns_data.map(&:to_h),
            primary: model.columns_primary.map(&:to_h),
            foreign_key: model.columns_foreign_key.map(&:to_h),
            foreign_type: model.columns_foreign_type.map(&:to_h),
            timestamp: model.columns_timestamp.map(&:to_h),
            deleted_at: model.columns_deleted_at.map(&:to_h),
            virtual: model.columns_virtual.map(&:to_h),
            data_foreign: model.columns_data_foreign.map(&:to_h),
            data_primary: model.columns_data_primary.map(&:to_h),
            data_virtual: model.columns_data_virtual.map(&:to_h),
            data_foreign_virtual: model.columns_data_foreign_virtual.map(&:to_h)
          }
        }
      end
    end
  end
end
