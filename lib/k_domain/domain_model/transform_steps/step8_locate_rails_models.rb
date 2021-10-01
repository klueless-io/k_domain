# frozen_string_literal: true

# Locate rails model files
class Step8LocateRailsModels < KDomain::DomainModel::Step
  attr_accessor :ruby_code

  def call
    raise 'ERD path not supplied' if opts[:erd_path].nil?

    self.rails_files_models = domain_models.map { |model| locate_rails_model(model[:name], model[:table_name]) }
  end

  private

  def locate_rails_model(table_name, model_name)
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
