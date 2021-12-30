# frozen_string_literal: true

# Locate rails model files
class Step6RailsStructureModels < KDomain::DomainModel::Step
  def call
    raise 'Rails model path not supplied' unless opts[:model_path]

    # THIS IS NOT WORKING YET
    self.rails_structure_models = rails_resource_models.map do |resource|
      process_resource(OpenStruct.new(resource))
    end

    attach_behavior_and_functions
  end

  private

  def process_resource(resource)
    {
      model_name: resource.model_name,
      table_name: resource.table_name,
      file: resource.file,
      exist: resource.exist,
      state: resource.state,
      code: resource.exist ? File.read(resource.file) : '',
      behaviours: {},
      functions: {}
    }

    # return @model unless  resource.exist

    # @model[:behaviours] = extract_behavior(resource.file)
    # @model[:functions] = extract_functions(resource.file)

    # @model
  end

  def attach_behavior_and_functions
    rails_structure_models.select { |model| model[:exist] }.each do |model|
      model[:behaviours] = extract_behavior(model[:file])
      klass_name = model[:behaviours][:class_name]
      model[:functions] = extract_functions(klass_name)
    end
  end

  def extract_behavior(file)
    extractor.extract(file)
    extractor.model
  end

  def extract_functions(klass_name)
    klass = klass_type(klass_name)

    return {} if klass.nil?

    Peeky.api.build_class_info(klass.new).to_h
  rescue StandardError => e
    log.exception(e)
  end

  def klass_type(klass_name)
    Module.const_get(klass_name.classify)
  rescue NameError
    puts ''
    puts klass_name
    puts klass_name.classify
    puts klass_name.pluralize
    puts 'Trying the pluralized version: '
    Module.const_get(klass_name.pluralize)
  end

  def extractor
    @extractor ||= KDomain::RailsCodeExtractor::ExtractModel.new(shim_loader)
  end

  def shim_loader
    return opts[:shim_loader] if !opts[:shim_loader].nil? && opts[:shim_loader].is_a?(KDomain::RailsCodeExtractor::ShimLoader)

    shim_loader = KDomain::RailsCodeExtractor::ShimLoader.new
    # Shims to attach generic class_info writers
    shim_loader.register(:attach_class_info           , KDomain::Gem.resource('templates/ruby_code_extractor/attach_class_info.rb'))
    shim_loader.register(:behaviour_accessors         , KDomain::Gem.resource('templates/ruby_code_extractor/behaviour_accessors.rb'))

    # Shims to support standard active_record DSL methods
    shim_loader.register(:active_record               , KDomain::Gem.resource('templates/rails/active_record.rb'))

    # Shims to support application specific [module, class, method] implementations for suppression and exception avoidance
    shim_loader
  end
end
