# frozen_string_literal: true

# Load sample DB schema
RSpec.shared_examples :load_db_schema do
  let(:load_db_schema_file) { 'spec/sample_output/raw_db_schema/schema.json' }

  let(:load_db_schema) do
    loader = KDomain::RawDbSchema::Load.new(load_db_schema_file)
    loader.call
    loader.data
  end
end
