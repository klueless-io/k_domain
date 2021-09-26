# frozen_string_literal: true

# Setup transformed JSON before load be used
RSpec.shared_examples :transform_db_schema do
  let(:raw_db_schema_file) { 'spec/samples/raw_db_schema.rb' }
  let(:raw_db_schema_json_file) { 'spec/samples/raw_db_schema.json' }

  let(:db_transform) do
    transformer = KDomain::RawDbSchema::Transform.new(raw_db_schema_file)
    transformer.call
    transformer.write_json(raw_db_schema_json_file)
    transformer.schema
  end
end