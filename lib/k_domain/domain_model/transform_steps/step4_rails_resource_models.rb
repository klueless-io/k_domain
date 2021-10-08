# frozen_string_literal: true

# Locate rails model files
class Step4RailsResourceModels < KDomain::DomainModel::Step
  attr_accessor :ruby_code

  def call
    raise 'Model path not supplied' if opts[:model_path].nil?

    self.rails_resource_models = domain_models.map do |model|
      locate_rails_model(model[:name], model[:table_name])
    end
  end

  private

  def locate_rails_model(model_name, table_name)
    file_normal = File.join(opts[:model_path], "#{model_name}.rb")
    file_custom = File.join(opts[:model_path], "#{table_name}.rb")
    file_exist  = true
    state = []

    if File.exist?(file_normal)
      file = file_normal
      state.push(:has_ruby_model)
    elsif File.exist?(file_custom)
      file = file_custom
      state.push(:has_ruby_model)
      state.push(:non_conventional_name)
    else
      file = ''
      file_exist = false
      state.push(:model_not_found)
    end

    {
      model_name: model_name,
      table_name: table_name,
      file: file,
      exist: file_exist,
      state: state.join(', ')
    }
  end
end
