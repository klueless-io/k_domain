# frozen_string_literal: true

# Load sample DB schema
RSpec.shared_examples :load_db_schema do
  let(:load_db_schema) do
    loader = KDomain::RawDbSchema::Load.new(db_schema_json_file)
    loader.call
    loader.data
  end
end
