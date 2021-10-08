# frozen_string_literal: true

# Locate rails model files
class Step6RailsStructureModels < KDomain::DomainModel::Step
  def call
    raise 'Rails model path not supplied' unless opts[:model_path]

    self.rails_structure_models = rails_resource_models.map do |resource|
      process_resource(OpenStruct.new(resource))
    end
  end

  private

  def process_resource(resource)
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

    return @model unless  resource.exist

    @model[:behaviours] = extract_model_behavior(resource.file)
    @model[:functions] = extract_model_functions(resource.file)

    @model
  end

  def extract_model_behavior(file)
    extractor.extract(file)
    extractor.model
  end

  def extract_model_functions(file)
    klass_name = File.basename(file, File.extname(file))

    klass = case klass_name
            when 'clearbit_quota'
              ClearbitQuota
            when 'account_history_data'
              AccountHistoryData
            else
              Module.const_get(klass_name.classify)
            end

    class_info = Peeky.api.build_class_info(klass.new)

    class_info.to_h
  rescue StandardError => e
    log.exception(e)
  end

  def extractor
    @extractor ||= KDomain::RailsCodeExtractor::ExtractModel.new(shim_loader)
  end

  def shim_loader
    return opts[:shim_loader] if !opts[:shim_loader].nil? && opts[:shim_loader].is_a?(KDomain::RailsCodeExtractor::ShimLoader)

    shim_loader = KDomain::RailsCodeExtractor::ShimLoader.new
    shim_loader.register(:fake_module  , KDomain::Gem.resource('templates/fake_module_shims.rb'))
    shim_loader.register(:active_record, KDomain::Gem.resource('templates/active_record_shims.rb'))
    shim_loader
  end
end
