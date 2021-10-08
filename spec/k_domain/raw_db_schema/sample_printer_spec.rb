# frozen_string_literal: true

RSpec.describe 'KDomain::RawDbSchema::SamplePrinter' do
  include KLog::Logging

  include_examples :simple_domain_settings
  include_examples :load_db_schema

  context 'print tables' do
    let(:graph) do
      {
        tables: {
          take: 4,
          columns: [
            :name,
            :primary_key,
            :primary_key_type,
            { index_count: { display_method: ->(row) { row.indexes.length } } },
            { column_count: { display_method: ->(row) { row.columns.length } } },
            { column_names: { width: 200, display_method: ->(row) { row.columns.take(5).map(&:name).join(', ') } } }
          ]
        },
        foreign_keys: { skip: true },
        indexes: { skip: true },
        meta: { skip: true }
      }
    end

    it do
      log.structure(load_db_schema, title: 'Rails Tables', line_width: 200, graph: graph)
    end
  end

  context 'print foreign keys' do
    let(:graph) do
      {
        tables: { skip: true },
        foreign_keys: {
          take: 4,
          columns: [
            :left,
            :right,
            { name: { width: 100 } },
            :on_update,
            :on_delete,
            :column
          ]
        },
        indexes: { skip: true },
        meta: { skip: true }
      }
    end

    it do
      log.structure(load_db_schema, title: 'Foreign Keys', line_width: 200, graph: graph)
    end
  end

  context 'print indexes' do
    let(:graph) do
      {
        tables: { skip: true },
        foreign_keys: { skip: true },
        indexes: {
          take: 4,
          columns: [
            :name,
            { fields: { width: 150, display_method: ->(row) { row.fields.join(', ') } } },
            :using,
            { order: { width: 100, display_method: ->(row) { row.order.to_h } } },
            :where,
            :unique
          ]
        },
        meta: { skip: true }
      }
    end

    it do
      log.structure(load_db_schema, title: 'All Indexes', line_width: 200, graph: graph)
    end
  end

  context 'print meta' do
    let(:graph) do
      {
        tables: { skip: true },
        foreign_keys: { skip: true },
        indexes: { skip: true },
        meta: {
          unique_keys: {
            columns: [
              :type,
              :category,
              { key: { width: 100 } },
              { keys: { width: 100, display_method: ->(row) { row.keys.take(5).join(', ') } } }
            ]
          }

        }
      }
    end

    it do
      log.structure(load_db_schema, title: 'Meta', line_width: 200, graph: graph)
    end
  end
end
