log.warn snake.parse('RailsDomainActions-Step4AttachModelDsl') if AppDebug.require?

# Attach source code found in rails model definitions to models
class Step5AttachDataDictionary < RailsDomain::Step
  attr_accessor :dictionary
  # Map database schema to domain model
  def run(domain_data:)
    self.domain_data = domain_data

    @dictionary = {}

    domain_models.each do |model|
      model[:columns].each do |column|
        process(model[:name], column[:name], column[:type])
      end
    end

    domain[:dictionary] = dictionary.values

    nil
  end

  private

  def process(model_name, column_name, column_type)
    if dictionary.key?(column_name)
      entry = dictionary[column_name]
      entry[:models] << model_name
      entry[:model_count] = entry[:model_count] + 1
      
      unless entry[:types].include?(column_type)
        log.warn("#{model_name} has a type mismatch for column name: #{column_name}")
        entry[:types] << column_type
        entry[:type_count] = entry[:type_count] + 1
      end
      return
    end

    dictionary[column_name] = {
      name:         column_name,
      type:         column_type,
      label:        titleize.parse(column_name.to_s),
      segment:      segment(column_name, column_type),
      models:       [model_name],
      model_count:  1,
      types:        [column_type],
      type_count:   1
    }
  rescue => exception
    # 
  end

  def segment(column_name, column_type)
    n = column_name.to_s
    return column_type == :integer ? :id : :id_variant if n.ends_with?('_id')
    return column_type == :datetime ? :stamp : :stamp_variant if n == 'created_at'
    :data
  end

end
