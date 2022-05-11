# frozen_string_literal: true

RSpec.shared_examples :domain_advanced_settings do
  let(:db_schema_ruby_file) { '/Users/davidcruwys/dev/printspeak/printspeak-master/db/schema.rb' }
  let(:db_schema_json_file) { 'spec/example_domain/advanced/output/schema.json' }
  let(:schema_loader_file)  { 'spec/example_domain/advanced/output/raw_db_schema/schema_loader.rb' }

  let(:model_path)          { '/Users/davidcruwys/dev/printspeak/printspeak-master/app/models' }
  let(:controller_path)     { '/Users/davidcruwys/dev/printspeak/printspeak-master/app/controllers' }
  let(:route_path)          { '/Users/davidcruwys/dev/printspeak/printspeak-master/routes.json' }

  let(:domain_model_file)   { 'spec/example_domain/advanced/output/domain_model/main_dataset.json' }
  let(:domain_model_step)   { 'spec/example_domain/advanced/output/domain_model/%{step}.json' }
end
