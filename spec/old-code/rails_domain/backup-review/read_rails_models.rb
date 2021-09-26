# log.warn snake.parse('RailsModelSchemaActions-ReadRailsModels') if AppDebug.require?

# # Modifies the original file and adds some helper methods so that the schema
# # file can be transformed into a hash
# class ReadRailsModels
#   attr_reader :context

#   def initialize(context)
#     @context = context
#   end

#   def run
#     log.section_heading 'ReadRailsModels.run'

#     # sync_old_source_code

#     map_tables_to_rails_models
#     attach_ruby_code_to_rails_models

#     # builder
#     #   .add_file(target_schema_file,
#     #     template_file: 'load_schema.rb',
#     #     rails_schema: lines.join,
#     #     source_file: source_schema_file)
#   end

#   # deprecate with migration is finished
#   def sync_old_source_code
#     old_path = '/Users/davidcruwys/dev/printspeak/printspeak/.builders/domain_objects'
#     new_path = '/Users/davidcruwys/dev/printspeak/reference_application/printspeak-domain/.builders/models/domain'

#     FileUtils.cp_r(Dir.glob("#{old_path}/*"), new_path)
#   end

#   def map_tables_to_rails_models
#     mapper = TableToRailsModelMapper.new
#     context.rails_models = context.table_names.map { |table_name| mapper.map(context.tables[table_name]) }
#   end

#   def attach_ruby_code_to_rails_models
#     context.rails_models.each { |model| attach_ruby_code(model) }
#     puts ''
#   end

#   def attach_ruby_code(model)
#     return unless model.exists?
#     print '.'
#     $stdout.flush

#     starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)

#     # puts starting.class.name
#     model.ruby_raw = File.read(model.model_path)

#     # Load file timer
#     model.time_stamp1 = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - starting).round(2)

#     regex_split_header_from_code = /(?<frozen># frozen_string_literal: true)?(?<header>.*?(?=(^\s*)(class|module)))?(?<code>(^\s*)(class|module).*)?/m
#     header_code = regex_split_header_from_code.match(model.ruby_raw)

#     model.time_stamp2 = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - starting + model.time_stamp1).round(2)

#     model.ruby_frozen = header_code[:frozen]
#     model.ruby_header = header_code[:header].strip
#     model.ruby_code = header_code[:code].strip
#     model.ruby_code = header_code[:code].strip

#     clean_code = model.ruby_code.gsub(/private_class_method/, 'XX1XX')
#     regex_split_private_public = /(?<public>.+?)(?<separated>^\s*\bprivate\b)(?<private>.*)/m

#     code = regex_split_private_public.match(clean_code)

#     model.time_stamp3 = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - starting + model.time_stamp1 + model.time_stamp2).round(2)

#     return unless code

#     model.ruby_code_public = code[:public].gsub(/XX1XX/, 'private_class_method')
#     model.ruby_code_private = code[:private].gsub(/XX1XX/, 'private_class_method')
#   end
# end
