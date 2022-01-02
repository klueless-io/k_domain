# frozen_string_literal: true

# Setup transformed JSON before load be used
RSpec.shared_examples :transform_db_schema do
  let(:db_transform) do
    transformer = KDomain::RawDbSchema::Transform.new(db_schema_ruby_file, transform_filter)
    transformer.call
    transformer.write_json(db_schema_json_file)
    transformer.write_schema_loader(schema_loader_file)
    transformer.schema
  end
end
