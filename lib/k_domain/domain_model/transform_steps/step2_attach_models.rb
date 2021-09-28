# frozen_string_literal: true

# Loop through the db_schema tables and build up a
# basic model for each table
class Step2AttachModels < KDomain::DomainModel::Step
  # Map database schema to domain model
  def call
    raise 'ERD path not supplied' if opts[:erd_path].nil?

    # Schema is re-shaped into a format designed for domain modeling
    domain[:models] = database_tables.map { |table| model(table) }
  end

  def model(table)
    table_name = table[:name].to_s
    model_name = table_name.singularize

    {
      name: model_name,
      name_plural: table_name, # need to check if this is correct as I know it is wrong for account_history_datum
      table_name: table_name,
      pk: primary_key(table),
      erd_location: location(table_name, model_name),
      statistics: {},                                   # Load in future step
      columns: []                                       # Load in future step
    }
  end

  def primary_key(table)
    {
      name: table[:primary_key],
      type: table[:primary_key_type],
      exist: !table[:primary_key].nil?
    }
  end

  # Location of source code
  def location(table_name, model_name)
    file_normal = File.join(opts[:erd_path], "#{model_name}.rb")
    file_custom = File.join(opts[:erd_path], "#{table_name}.rb")
    file_exist  = true
    state = []

    if File.exist?(file_normal)
      file = file_normal
      state.push(:has_ruby_model)
    elsif File.exist?(file_custom)
      file = file_custom
      state.push(:has_ruby_model)
      state.push(:nonconventional_name)
    else
      file = ''
      file_exist = false
    end

    {
      file: file,
      exist: file_exist,
      state: state                      # display_state: state.join(' ')
    }
  end
end
