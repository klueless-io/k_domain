# frozen_string_literal: true

RSpec.describe "KDomain::RawDbSchema::SamplePrinter" do
  include KLog::Logging

  include_examples :load_db_schema

  # let(:load_db_schema_file) { 'spec/sample_output/raw_db_schema/schema.json' }

  context 'print tables' do
    let(:graph) do
      {
        tables: {
          # heading: 'Database Tables',
          take: :all,
          columns: [
            :name,
            :primary_key,
            :primary_key_type,
            { index_count: { display_method: -> (row) { row.indexes.length } } },
            { column_count: { display_method: -> (row) { row.columns.length } } },
            { column_names: { width: 200, display_method: -> (row) { row.columns.take(5).map { |c| c.name }.join(', ') } } }
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

  context 'print tables' do
    let(:graph) do
      {
        tables: { skip: true },
        foreign_keys: {
          take: :all,
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
          # heading: "PostgreSQL - All indexes",
          take: :all,
          columns: [
            :name,
            { fields: { width: 150, display_method: -> (row) { row.fields.join(', ') } } },
            :using,
            { order: { width: 100, display_method: -> (row) { row.order.to_h } } },
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
end
