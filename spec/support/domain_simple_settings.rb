# frozen_string_literal: true

RSpec.shared_examples :domain_simple_settings do
  let(:db_schema_ruby_file) { 'spec/example_domain/simple/input/schema.rb' }
  let(:db_schema_json_file) { 'spec/example_domain/simple/output/raw_db_schema/schema.json' }
  let(:schema_loader_file)  { 'spec/example_domain/simple/output/raw_db_schema/schema_loader.rb' }

  let(:model_path)          { File.expand_path('spec/example_domain/simple/input/models') }
  let(:controller_path)     { File.expand_path('spec/example_domain/simple/input/controllers') }
  let(:route_path)          { File.expand_path('spec/example_domain/simple/input/routes.json') }

  let(:domain_model_file)   { 'spec/example_domain/simple/output/domain_model/main_dataset.json' }
  let(:domain_model_step)   { 'spec/example_domain/simple/output/domain_model/%{step}.json' }
end
