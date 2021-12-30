# frozen_string_literal: true

#  columns to models
class Step8DomainColumns < KDomain::DomainModel::Step
  attr_reader :domain_model
  attr_reader :domain_column
  attr_reader :rails_model
  attr_reader :column_name
  attr_reader :column_symbol

  def call
    enrich_columns
  end

  def enrich_columns
    # .select {|m| m[:name] == 'app_user'}
    domain_models.each do |model|
      @domain_model = model
      # this will be nil if there is no rails model code
      @rails_model = find_rails_structure_models(domain_model[:name])

      # log.warn domain_model[:name]
      domain_model[:columns].each do |column|
        @domain_column = column
        @column_name = column[:name]
        @column_symbol = column[:name].to_sym

        attach_foreign_key
        column[:structure_type] = structure_type
      end
    end
  end

  def expand_column(column)
    foreign_table = lookup_foreign_table(column_name)
    is_foreign = !foreign_table.nil?
    # is_foreign = foreign_key?(column_name)
    structure_type = structure_type(is_foreign)

    column.merge({
                   structure_type: structure_type,
                   foreign_key: is_foreign,
                   foreign_table: (foreign_table || '').singularize,
                   foreign_table_plural: (foreign_table || '').pluralize
                 })
  end

  def lookup_foreign_table(column_name)
    foreign_table = find_foreign_table(table[:name], column_name)

    return foreign_table if foreign_table

    cn = column_name.to_s

    if cn.ends_with?('_id')
      table_name = column_name[0..-4]
      table_name_plural = table_name.pluralize

      if table_name_exist?(table_name_plural.to_s)
        investigate(step: :step8_columns,
                    location: :lookup_foreign_table,
                    key: column_name,
                    message: "#{@table[:name]}.#{column_name} => #{table_name_plural} - Relationship not found in DB, so have inferred this relationship. You may want to check that this relation is correct")

        return table_name
      end

      investigate(step: :step8_columns,
                  location: :lookup_foreign_table,
                  key: column_name,
                  message: "#{@table[:name]}.#{column_name} => #{table_name_plural} - Table not found for a column that looks like foreign_key")
    end

    nil
  end

  def attach_foreign_key
    return if rails_model.nil? || rails_model[:behaviours].nil? || rails_model[:behaviours][:belongs_to].nil?

    foreign = rails_model[:behaviours][:belongs_to].find { |belong| belong[:opts][:foreign_key].to_sym == domain_column[:name].to_sym }

    return unless foreign

    # NEED TO PRE-LOAD the table, table_plural and model
    domain_column[:foreign_table] = 'xxx1'
    domain_column[:foreign_table_plural] = 'xxx3'
    domain_column[:foreign_model] = 'xxx2'
  end

  # Need some configurable data dictionary where by
  # _token can be setup on a project by project basis
  def structure_type
    return :primary_key         if domain_model[:pk][:name] == column_name
    return :foreign_key         if domain_column[:foreign_table]

    return :timestamp           if column_symbol == :created_at || column_symbol == :updated_at
    return :timestamp           if column_symbol == :created_at || column_symbol == :updated_at
    return :deleted_at          if column_symbol == :deleted_at
    return :encrypted_password  if column_symbol == :encrypted_password
    return :token               if column_name.ends_with?('_token') || column_name.ends_with?('_token_iv')

    :data
  end
end
