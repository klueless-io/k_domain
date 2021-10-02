# frozen_string_literal: true

RSpec.describe 'KDomain::DomainModelSchema::SamplePrinter' do
  include KLog::Logging

  include_examples :load_domain_model

  let(:root_graph) {
    {
      investigate: { skip: true },
      domain: { skip: true },
      rails: { skip: true },
      rail_files: { skip: true },
      database: { skip: true }
    }
  }

  # let(:load_domain_model_file) { 'spec/sample_output/printspeak/domain_model.json' }

  def show_length(array)
    return '' if array.nil?

    length = array.length
    length.zero? ? '' : length
  end

  context 'print tables' do
    let(:graph) do
      {
        models: {
          title: 'Models',
          take: 4,
          columns: [
            :name,
            :name_plural,
            :table_name,
            :type,
            { pk:               { display_method: ->(row) { row.pk.name                            } } },
            { pk_type:          { display_method: ->(row) { row.pk.type                            } } },
            { pk_exist:         { display_method: ->(row) { row.pk.exist                           } } },
            { ruby_exist:       { display_method: ->(row) { row.erd_location.exist                 } } },
            # TODO: :main_key,
            # TODO: { traits:           { display_method: -> (row) { row.traits.join(',')                   } } },
            { column_count:     { display_method: ->(row) { show_length(row.columns)               } } },
            { for_data:         { display_method: ->(row) { show_length(row.columns_data)          } } },
            { for_primary:      { display_method: ->(row) { show_length(row.columns_primary)       } } },
            { for_foreign:      { display_method: ->(row) { show_length(row.columns_foreign)       } } },
            { for_timestamp:    { display_method: ->(row) { show_length(row.columns_timestamp)     } } },
            { for_deleted_at:   { display_method: ->(row) { show_length(row.columns_deleted_at)    } } },
            { for_virtual:      { display_method: ->(row) { show_length(row.columns_virtual)       } } },
            { for_data_foreign: { display_method: ->(row) { show_length(row.columns_data_foreign)  } } }
          ]
        },
        erd_files: { skip: true },
        dictionary: { skip: true }
      }
    end

    it do
      log.structure(load_domain_model.domain, title: 'Models', line_width: 200, graph: graph)
    end
  end

  context 'print erd_files' do
    let(:graph) do
      {
        models: { skip: true },
        erd_files: {
          title: 'ERD Files',
          take: 4,
          columns: [
            :name,
            :name_plural,
            { dsl_file:                 { display_method: ->(row) { File.basename(row.dsl_file) } } },
            { ruby:                     { display_method: ->(row) { row.source&.ruby ? 'true' : '' } } },
            { has_public:               { display_method: ->(row) { row.source&.public ? 'true' : '' } } },
            { has_private:              { display_method: ->(row) { row.source&.private ? 'true' : '' } } },
            { class_methods:            { display_method: ->(row) { show_length(row.source&.all_methods&.klass) } } },
            { instance_methods:         { display_method: ->(row) { show_length(row.source&.all_methods&.instance) } } },
            { instance_public:          { display_method: ->(row) { show_length(row.source&.all_methods&.instance_public) } } },
            { instance_private:         { display_method: ->(row) { show_length(row.source&.all_methods&.instance_private) } } },
            { scopes:                   { display_method: ->(row) { show_length(row.dsl&.scopes) } } },
            { belongs_to:               { display_method: ->(row) { show_length(row.dsl&.belongs_to) } } },
            { has_one:                  { display_method: ->(row) { show_length(row.dsl&.has_one) } } },
            { has_many:                 { display_method: ->(row) { show_length(row.dsl&.has_many) } } },
            { has_and_belongs_to_many:  { display_method: ->(row) { show_length(row.dsl&.has_and_belongs_to_many) } } },
            { validate_on:              { display_method: ->(row) { show_length(row.dsl&.validate_on) } } },
            { validates_on:             { display_method: ->(row) { show_length(row.dsl&.validates_on) } } }
          ]
        },
        dictionary: { skip: true }
      }
    end

    it do
      log.structure(load_domain_model.domain, title: 'ERD Files', line_width: 200, graph: graph)
    end
  end

  context 'print dictionary' do
    let(:graph) do
      {
        models: { skip: true },
        dictionary: {
          title: 'Dictionary',
          take: 4,
          columns: [
            :name,
            :type,
            :label,
            :segment,
            :model_count,
            { models: { width: 80, display_method: ->(row) { row.models.reject { |name| name == '__EFMigrationsHistory' || name.start_with?('asp_') }.join(', ') } } },
            :type_count,
            { types: { width: 40, display_method: ->(row) { row.types.join(', ') } } }
          ]
        },
        erd_files: { skip: true }
      }
    end

    it do
      log.structure(load_domain_model.domain, title: 'Dictionary', line_width: 200, graph: graph)
    end
  end

  context 'print investigations' do
    let(:graph) do
      {
        investigate: {
          title: 'Investigations',
          issues: {
            take: 4,
            columns: [
              :step,
              :location,
              :key,
              { message: { width: 200 } }
            ]
          },
        }
      }
    end

    it do
      log.structure(load_domain_model,
                    title: 'Investigations',
                    line_width: 200,
                    graph: root_graph.merge(graph))
    end
  end

  context 'print rails resources' do
    let(:graph) do
      {
        rails_files: {
          models: {
            # pry_at: [:before_array],
            take: 4,
            title: 'Resource path - Rails Models',
            columns: [
              :model_name,
              :table_name,
              { file: { width: 200 } },
              :exist,
              { state: { width: 40 } },
            ]
          },
          controllers: { skip: true }
        }
      }
    end

    it do
      log.structure(load_domain_model,
                    title: 'Rails Resources - Models',
                    line_width: 200,
                    graph: root_graph.merge(graph))
    end
  end
end
