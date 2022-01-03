# frozen_string_literal: true

#  columns to models
class Step8DomainColumns < KDomain::DomainModel::Step
  attr_reader :domain_model
  attr_reader :domain_column
  attr_reader :rails_model
  attr_reader :column_name
  attr_reader :column_symbol

  def call
    @debug = true
    enrich_columns
  end

  def enrich_columns
    # .select {|m| m[:name] == 'app_user'}
    domain_models.each do |model|
      @domain_model = enrich_model(model)
      # this will be nil if there is no rails model code

      # log.warn domain_model[:name]
      domain_model[:columns].each do |column|
        @domain_column = column
        @column_name = column[:name]
        @column_symbol = column[:name].to_sym

        column[:structure_type] = structure_type
      end
    end
  end

  def enrich_model(model)
    # NOTE: THIS MAY GET MOVED TO DomainModel::Load#enrichment
    @rails_model = find_rails_structure_models(model[:name])

    model[:file] = @rails_model[:file]

    log.error "Rails model not found for: #{model[:name]}" unless @rails_model

    model
  end

  # Need some configurable data dictionary where by
  # _token can be setup on a project by project basis
  def structure_type
    return :primary_key         if domain_model[:pk][:name] == column_name
    return :foreign_key         if foreign_relationship?

    return :timestamp           if column_symbol == :created_at || column_symbol == :updated_at
    return :timestamp           if column_symbol == :created_at || column_symbol == :updated_at
    return :deleted_at          if column_symbol == :deleted_at
    return :encrypted_password  if column_symbol == :encrypted_password
    return :token               if column_name.ends_with?('_token') || column_name.ends_with?('_token_iv')

    :data
  end

  def foreign_relationship?
    return false if rails_model.nil? || rails_model[:behaviours].nil? || rails_model[:behaviours][:belongs_to].nil?

    column_name = domain_column[:name].to_sym
    rails_model[:behaviours][:belongs_to].any? { |belong| belong[:opts][:foreign_key].to_sym == column_name }
  end

  # def attach_relationships
  #   domain_column[:relationships] = []
  #   return if rails_model.nil? || rails_model[:behaviours].nil? || rails_model[:behaviours][:belongs_to].nil?

  #   column_name = domain_column[:name].to_sym

  #   attach_column_relationships(column_name)
  # end

  # def select_belongs_to(column_name)
  #   rails_model[:behaviours][:belongs_to].select { |belong| belong[:opts][:foreign_key].to_sym == column_name.to_sym }
  # end

  # # this just maps basic relationship information,
  # # to go deeper you really need to use the Rails Model Behaviours
  # def attach_column_relationships(column_name)
  #   select_belongs_to(column_name).each do |belongs_to|
  #     domain_column[:relationships] << map_belongs_to(belongs_to)
  #   end
  # end

  # def map_belongs_to(belongs_to)
  #   @domain_column[:structure_type] = :foreign_key
  #   # result = {
  #   #   type: :belongs_to,
  #   #   name: belongs_to[:name],
  #   #   foreign_key: belongs_to.dig(:opts, :foreign_key) || @domain_column[:name],
  #   # }

  #   # result[:primary_key] = belongs_to.dig(:opts, :primary_key) if belongs_to.dig(:opts, :primary_key)
  #   # result[:class_name] = belongs_to.dig(:opts, :class_name) if belongs_to.dig(:opts, :class_name)
  #   result
  # end
end
