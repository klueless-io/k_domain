# log.warn snake.parse('RailsModelSchemaActions') if AppDebug.require?

# require_relative './build_domain_model'
# require_relative './read_rails_models'
# require_relative './rails_model_context'

# # Takes a DB schema.json file, iterates the tables and reads the source code
# # within rails model.rb files looking for DSL methods and other code that can
# # help develop are rich schema.
# class RailsDomainActions < BaseAction
#   attr_reader :filter
#   attr_reader :domain

#   def initialize(context, opts, filter)
#     super(context, opts)

#     @filter = filter

#     @valid = true

#     # G.custom_actions.generate_guards(required: %i[read_models show_read_model show_read_model_format build_domain_model source_schema_json_file source_model_path target_schema_json_file])
#     guard('missing option source_schema_json_file')     if opts.source_schema_json_file.nil?
#     guard('missing option source_model_path')           if opts.source_model_path.nil?
#     guard('missing option target_schema_json_file')     if opts.target_schema_json_file.nil?

#     guard('missing option read_models')                 if opts.read_models.nil?
#     guard('missing option show_read_model')             if opts.show_read_model.nil?
#     guard('missing option show_read_model_format')      if opts.show_read_model_format.nil?
#     guard('missing option generate_json')               if opts.generate_json.nil?
#     guard('missing option open_json')                   if opts.open_json.nil?

#     guard('missing option build_domain_model')          if opts.build_domain_model.nil?
#     guard('missing option show_domain_model')           if opts.show_domain_model.nil?
#     guard('missing option show_domain_model_format')    if opts.show_domain_model_format.nil?
#   end

#   def execute
#     return unless execute?

#     # @context = RailsModelContext.new(opts.source_schema_json_file)

#     # read_models                             if opts.read_models

#     # if opts.build_domain_model
#     #   log.error 'no tables provided'        if @context.tables.length == 0
#     #   log.error 'no rails models provided'  if @context.rails_models.length == 0
#     #   build_domain_model
#     # end

#     # return unless opts.generate_json

#     # return guard('you need to turn on [build_domain_model] if you want to generate_json') unless opts.build_domain_model

#     # @context.write_json(opts.target_schema_json_file)

#     # builder.vscode(opts.target_schema_json_file)
#   end

#   def read_models
#     # Loads the rails model.rb code into data objects for each table
#     action = ReadRailsModels.new(context)
#     action.run

#     return unless opts.show_read_model

#     if opts.show_read_model_format == :basic
#       print_models_basic
#     else
#       if opts.show_read_model_format == :instrumentation
#         print_models_detailed_instrumentation
#       else
#         print_models_detailed
#       end
#       print_stats
#     end
#   end

#   def build_domain_model
#     print_stats
#     action = BuildDomainModel.new(context)
#     action.run
#     @domain = action.domain

#     print_domain if opts.show_domain_model && opts.show_domain_model_format.length > 0
#   end

#   def print_domain
#     return guard('no domain provided') if domain.nil?

#     opts.show_domain_model_format.each do |format|
#       log.section_heading( "Domain: #{domain.name}")    if format == :basic
#       print_domain_stats                                if format == :domain_stats
#       print_domain_entities                             if format == :entities
#     end
#   end

#   def print_domain_stats
#     domain.statistics.print
#   end

#   def filtered_domain_entities
#     filter_data(domain.entities)
#   end

#   def print_domain_entities
#     log.warn('Entities ::')
#     tp filtered_domain_entities, :name, :name_plural, :id, :force
#   end

#   def filter_data(data)
#     return data unless filter.active

#     if filter.paginate
#       size        = data.length-1
#       start_index = filter.page_offset.nil? || filter.page_offset < 0 || filter.page_offset > size ? 0 : filter.page_offset
#       page_take   = filter.page_take.nil? ? 10000 : filter.page_take
#       end_index   = start_index + page_take-1
#       end_index   = size if end_index > size
#       # x = { size: size, start_index: start_index, end_index: end_index }
#       data = data[start_index..end_index]
#     end

#     data
#   end

#   def filtered_models
#     filter_data(context.rails_models)
#   end
  
#   def print_models_basic
#     tp filtered_models,
#     :name_original,
#     :name,
#     :name_plural,
#     :id,
#     :primary_key,
#     :force,
#     :display_quirks,
#     :ruby_raw
#   end

#   def print_models_detailed
#     tp filtered_models,
#       :name_original,
#       :name,
#       :name_plural,
#       :id,
#       :primary_key,
#       :force,
#       :display_quirks,
#       :ruby_raw,
#       :code_length,
#       :ruby_frozen,
#       :ruby_header,
#       :ruby_code_public,
#       :ruby_code_private
#   end

#   def print_models_detailed_instrumentation
#     tp filtered_models,
#       :name_original,
#       :name,
#       :name_plural,
#       :id,
#       :primary_key,
#       :force,
#       :display_quirks,
#       :ruby_raw,
#       :time_stamp1,
#       :time_stamp2,
#       :time_stamp3,
#       :code_length,
#       :ruby_frozen,
#       :ruby_header,
#       :ruby_code_public,
#       :ruby_code_private
#   end

#   def print_stats
#     log.kv 'table count'  , context.rails_models.length
#     log.kv 'models count' , context.rails_models.select { |m| m.quirks.include?(:has_ruby_model) }.length
#     log.kv 'm2m table'    , context.rails_models.select { |m| m.quirks.include?(:m2m_table) }.length
#     log.kv 'unconventional_name' , context.rails_models.select { |m| m.quirks.include?(:custom_name) }.length
#   end

#   alias :valid? :valid

#   private

#   def guard(message)
#     log.error message
#     @valid = false
#   end
# end
