# frozen_string_literal: true

# Locate rails model files
class Step9RailsStructureModels < KDomain::DomainModel::Step
  attr_accessor :ruby_code

  def call
    raise 'ERD path not supplied' if opts[:erd_path].nil?

    self.rails_structure_models = rails_resource_models.map do |resource|
      process_resource(OpenStruct.new(resource))
    end
  end

  private

  def process_resource(resource)
    erd_path = opts[:erd_path]
    puts erd_path
    @model = {
      model_name: resource.model_name,
      table_name: resource.table_name,
      file: resource.file,
      exist: resource.exist,
      state: resource.state,
      code: resource.exist ? File.read(resource.file) : '',
      behaviours: {},
      functions: {}
    }

    @model
  end
end
