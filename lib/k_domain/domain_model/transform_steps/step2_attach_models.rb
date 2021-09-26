# frozen_string_literal: true

# Loop through the db_schema tables and build up a
# basic model for each table
class Step2AttachModels < KDomain::DomainModel::Step
  # Map database schema to domain model
  def call
    guard('tables are missing')               if database[:tables].nil?
    guard('indexes are missing')              if database[:indexes].nil?
    guard('foreign keys are missing')         if database[:foreign_keys].nil?
    guard('rails version is missing')         if database[:meta][:rails].nil?
    guard('postgres extensions are missing')  if database[:meta][:database][:extensions].nil?
    guard('unique keys are missing')          if database[:meta][:unique_keys].nil?
  end
end


# log.warn snake.parse('RailsDomainActions-Step2AttachModels') if AppDebug.require?

# # Modifies the original file and adds some helper methods so that the schema
# # file can be transformed into a hash
# class Step2AttachModels < RailsDomain::Step
#   # Map database schema to domain model
#   def run(domain_data:)
#     self.domain_data = domain_data
    
#     build_models
#   end

#   private

#   # Schema is rewritten into a format designed for domain modal
#   def build_models
#     domain[:models] = database_tables.map { |table| model(table) }
#   end

#   def model(table)
#     table_name = table[:name].to_s
#     model_name = singularize.parse(table_name)

#     # Future fields
#     # -------------
#     # force: table[:force], # uncomment if we ever need the DB cascade available in models, it is still in the database schema
#     {
#       name: model_name,
#       name_plural: table_name, # need to check if this is correct as I know it is wrong for account_history_datum
#       table_name: table_name,
#       pk: primary_key(table),
#       location: location(table_name, model_name),     # maybe move to rails_model / rails_code
#       statistics: {},                                 # Load in future step
#       columns: []                                     # Load in future step
#     }
#   end

#   def primary_key(table)
#     {
#       name: table[:primary_key],
#       type: table[:primary_key_type],
#       exist: !table[:primary_key].nil?,
#     }
#   end

#   # def statistics(_table)
#   #   {
#   #     code_counts:     { flag: :not_set, instance: 0, public_instance: 0, private_instance: 0, class: 0, public_class: 0, private_class: 0 },
#   #     code_dsl_counts: { scopes: 0, has_many: 0, has_and_belongs_to_many: 0, belongs: 0, has_one: 0, validates: 0, validate: 0 },
#   #     column_counts:   { flag: :not_set, all: 0, id: 0, timestamp: 0, data: 0, foreign_key: 0 },
#   #     row_counts:      { au: 0, us: 0, eu: 0 },
#   #     issues:          []
#   #   }
#   # end

#   # column_names = table[:columns].map { |column| column[:name] }
      
#   # table[:column_count] = table[:columns].length
#   # table[:display_column_count] = table[:column_count].to_s

#   # Location of source code
#   def location(table_name, model_name)
#     file_normal = File.join(opts.source_model_path, "#{model_name}.rb")
#     file_custom = File.join(opts.source_model_path, "#{table_name}.rb")
#     file_exist  = true
#     state = []

#     if File.exist?(file_normal)
#       file = file_normal
#       state.push(:has_ruby_model)
#     elsif File.exist?(file_custom)
#       file = file_custom
#       state.push(:has_ruby_model)
#       state.push(:nonconventional_name)
#     else
#       file = ''
#       file_exist  = false
#     end

#     {
#       file: file,
#       exist: file_exist,
#       state: state                      # display_state: state.join(' ')
#     }
#   end
# end
