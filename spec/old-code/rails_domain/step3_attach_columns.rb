log.warn snake.parse('RailsDomainActions-Step3AttachColumns') if AppDebug.require?

# Attach columns to models
class Step3AttachColumns < RailsDomain::Step
  attr_accessor :table
  attr_reader :column_name
  attr_reader :column_symbol

  # Map database schema to domain model
  def run(domain_data:)
    self.domain_data = domain_data

    build_columns
  end

  private

  # Schema is rewritten into a format designed for domain modal
  def build_columns
    domain_models.each do |model|
      @table = find_table_for_model(model)
      columns = columns(table[:columns])
      columns = insert_primary_key(model, columns)
      model[:columns] = columns
    end
  end

  def column_data(name)
    @column_name   = name
    @column_symbol = name.to_sym
    { 
      name: name,
      name_plural: pluralize.parse(name),
      type: nil,
      precision: nil,
      scale: nil,
      default: nil,
      null: nil,
      limit: nil,
      array: nil
    }
  end

  def columns(db_columns)
    db_columns.map do |db_column|
      column = column_data(db_column[:name]).merge(
        type: check_type(db_column[:type]),
        precision: db_column[:precision],
        scale: db_column[:scale],
        default: db_column[:default],
        null: db_column[:null],
        limit: db_column[:limit],
        array: db_column[:array]
      )
  
      expand_column(column)
    end
  end

  def insert_primary_key(model, columns)
    return columns unless model[:pk][:exist]

    column = column_data("id").merge(
      type: check_type(model[:pk][:type]),
    )

    columns.unshift(expand_column(column))
    columns
  end

  def expand_column(column)
    foreign_table = lookup_foreign_table(column_name)
    is_foreign = !foreign_table.nil?
    # is_foreign = foreign_key?(column_name)
    structure_type = structure_type(is_foreign)

    column.merge({
      structure_type: structure_type,
      foreign_key: is_foreign,
      foreign_table:  singularize.parse(foreign_table) || '',
      foreign_table_plural:  pluralize.parse(foreign_table) || ''
    })
  end

  def check_type(type)
    type = type.to_sym if type.is_a?(String)

    return type if %i[string integer bigint bigserial boolean float decimal datetime date hstore text jsonb].include?(type)

    if type.nil?
      guard("nil type detected for db_column[:type]")

      return :string 
    end

    guard("new type detected for db_column[:type] - #{type}")
      
    camel.parse(type.to_s).downcase
  end

  def lookup_foreign_table(column_name)
    foreign_table = find_foreign_table(table[:name], column_name)

    return foreign_table if foreign_table

    cn = column_name.to_s

    if cn.ends_with?('_id')
      table_name = column_name[0..-4]
      table_name_plural = pluralize.parse(table_name)

      if table_name_exist?(table_name_plural.to_s)
        investigate(step: :step3_attach_columns,
          location: :lookup_foreign_table,
          key: column_name,
          message: "#{@table[:name]}.#{column_name} => #{table_name_plural} - Relationship not found in DB, so have inferred this relationship. You may want to check that this relation is correct")

        return table_name 
      end

      investigate(step: :step3_attach_columns,
                  location: :lookup_foreign_table,
                  key: column_name,
                  message: "#{@table[:name]}.#{column_name} => #{table_name_plural} - Table not found for a column that looks like foreign_key")
    end

    nil
  end

  # Need some configurable data dictionary where by
  # _token can be setup on a project by project basis
  def structure_type(is_foreign)
    return :foreign_key         if is_foreign
    return :primary_key         if column_symbol == :id
    return :timestamp           if column_symbol == :created_at || column_symbol == :updated_at
    return :timestamp           if column_symbol == :created_at || column_symbol == :updated_at
    return :deleted_at          if column_symbol == :deleted_at
    return :encrypted_password  if column_symbol == :encrypted_password
    return :token               if column_name.ends_with?('_token') || column_name.ends_with?('_token_iv')

    :data
  end
end
