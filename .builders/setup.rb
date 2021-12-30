require 'config/_'
require_relative "../lib/k_domain"

db_schema_ruby_file = '/Users/davidcruwys/dev/printspeak/printspeak-master/db/schema.rb'

# /Users/davidcruwys/dev/printspeak/printspeak/.builders/config/raw/schema_printspeak.rb
output_folder = File.expand_path('../.output')
db_schema_json_file = File.join(output_folder, 'db_schema.json')
schema_loader_file = File.join(output_folder, 'schema_printspeak.rb')

transformer = KDomain::RawDbSchema::Transform.new(db_schema_ruby_file)
transformer.template_file = '/Users/davidcruwys/dev/kgems/k_domain/templates/old_printspeek_schema.rb'
puts db_schema_ruby_file
puts transformer.template_file
transformer.call
transformer.write_json(db_schema_json_file)
transformer.write_schema_loader(schema_loader_file)
# transformer.schema


# transform = KDomain::DomainModel::Transform.new(
#   db_schema: db_schema,
#   target_file: target_file,
#   target_step_file: target_step_file,
#   model_path: model_path,
#   controller_path: controller_path,
#   route_path: route_path
# )

puts 'done'