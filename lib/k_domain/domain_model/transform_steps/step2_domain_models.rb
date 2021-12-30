# frozen_string_literal: true

# Schema is re-shaped into a format designed for domain modeling
class Step2DomainModels < KDomain::DomainModel::Step
  # Map database schema to domain model
  def call
    raise 'Rails model path not supplied' if opts[:model_path].nil?

    domain[:models] = database_tables.map { |table| model(table) }
  end

  def model(table)
    table_name = table[:name].to_s
    model_name = table_name.singularize

    model = {
      name: model_name,
      name_plural: table_name, # need to check if this is correct as I know it is wrong for account_history_datum
      table_name: table_name,
      pk: primary_key(table),
      file: nil
    }

    attach_columns(model)
  end

  def primary_key(table)
    {
      name: table[:primary_key],
      type: table[:primary_key_type],
      exist: !table[:primary_key].nil?
    }
  end

  def attach_columns(model)
    table = find_table_for_model(model)
    columns = columns(table[:columns])
    columns = insert_primary_key(model, columns)
    model[:columns] = columns
    model
  end

  def columns(db_columns)
    db_columns.map do |db_column|
      column_data(db_column[:name]).merge(
        type: check_type(db_column[:type]),
        precision: db_column[:precision],
        scale: db_column[:scale],
        default: db_column[:default],
        null: db_column[:null],
        limit: db_column[:limit],
        array: db_column[:array]
      )
    end
  end

  def insert_primary_key(model, columns)
    return columns unless model[:pk][:exist]

    column = column_data('id').merge(
      type: check_type(model[:pk][:type])
    )

    columns.unshift(column)
    columns
  end

  def check_type(type)
    type = type.to_sym if type.is_a?(String)

    return type if %i[string integer bigint bigserial boolean float decimal datetime date hstore text jsonb].include?(type)

    if type.nil?
      guard('nil type detected for db_column[:type]')

      return :string
    end

    guard("new type detected for db_column[:type] - #{type}")

    camel.parse(type.to_s).downcase
  end

  def column_data(name)
    {
      name: name,
      name_plural: name.pluralize,
      type: nil,
      precision: nil,
      scale: nil,
      default: nil,
      null: nil,
      limit: nil,
      array: nil
    }
  end

  # # Location of source code
  # def location(table_name, model_name)
  #   file_normal = File.join(opts[:model_path], "#{model_name}.rb")
  #   file_custom = File.join(opts[:model_path], "#{table_name}.rb")
  #   file_exist  = true
  #   state = []

  #   if File.exist?(file_normal)
  #     file = file_normal
  #     state.push(:has_ruby_model)
  #   elsif File.exist?(file_custom)
  #     file = file_custom
  #     state.push(:has_ruby_model)
  #     state.push(:nonconventional_name)
  #   else
  #     file = ''
  #     file_exist = false
  #   end

  #   {
  #     file: file,
  #     exist: file_exist,
  #     state: state
  #   }
  # end
end
