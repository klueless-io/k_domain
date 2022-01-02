# frozen_string_literal: true

# Locate rails controller files
class Step7RailsStructureControllers < KDomain::DomainModel::Step
  attr_accessor :controllers

  def call
    raise 'Rails controller path not supplied' unless opts[:controller_path]

    @controllers = {}

    rails_resource_routes.map do |route|
      process_route(OpenStruct.new(route))
    end

    self.rails_structure_controllers = controllers.keys.map { |key| controllers[key] }

    attach_behavior_and_functions
  end

  private

  def process_route(route)
    if new_controller?(route)
      new_controller(route)
    else
      controller = @controllers[route[:controller_file]]
      controller[:actions] << new_action(route)
    end
  end

  def new_controller?(route)
    !controllers.key?(route[:controller_file])
  end

  def new_controller(route)
    controllers[route[:controller_file]] = {
      name: route[:controller_name],
      path: route[:controller_path],
      namespace: route[:controller_namespace],
      file: route[:controller_file],
      exist: route[:controller_exist],
      full_file: route[:file],
      behaviours: {},
      functions: {},
      actions: [new_action(route)]
    }
  end

  def new_action(route)
    {
      route_name: route[:name],
      action: route[:action],
      uri_path: route[:uri_path],
      mime_match: route[:mime_match],
      verbs: route[:verbs]
    }
  end

  def attach_behavior_and_functions
    rails_structure_controllers.select { |controller| controller[:exist] }.each do |controller|
      unless File.exist?(controller[:full_file])
        log.error 'Controller apparently exists but no file found, this means that you need re-run rake routes'
        puts controller[:full_file]
        next
      end
      controller[:behaviours] = extract_behavior(controller[:full_file])
      klass_name = controller[:behaviours][:class_name]
      controller[:functions] = extract_functions(klass_name, controller[:full_file])
    end
  end

  def extract_behavior(file)
    # puts file
    extractor.extract(file)
    extractor.controller
  end

  def extractor
    @extractor ||= KDomain::RailsCodeExtractor::ExtractController.new(shim_loader)
  end

  def shim_loader
    return opts[:shim_loader] if !opts[:shim_loader].nil? && opts[:shim_loader].is_a?(KDomain::RailsCodeExtractor::ShimLoader)

    shim_loader = KDomain::RailsCodeExtractor::ShimLoader.new
    # Shims to attach generic class_info writers
    shim_loader.register(:attach_class_info           , KDomain::Gem.resource('templates/ruby_code_extractor/attach_class_info.rb'))
    shim_loader.register(:behaviour_accessors         , KDomain::Gem.resource('templates/ruby_code_extractor/behaviour_accessors.rb'))

    # Shims to support stand rails controller DSL methods
    shim_loader.register(:action_controller           , KDomain::Gem.resource('templates/rails/action_controller.rb'))

    # Shims to support application specific [module, class, method] implementations for suppression and exception avoidance
    # shim_loader.register(:app_action_controller       , KDomain::Gem.resource('templates/advanced/action_controller.rb'))
    # shim_loader.register(:app_controller_interceptors , KDomain::Gem.resource('templates/advanced/controller_interceptors.rb'))
    shim_loader
  end

  def extract_functions(klass_name, controller_file)
    klass = Module.const_get(klass_name.classify)

    class_info = Peeky.api.build_class_info(klass.new)

    class_info.to_h
  rescue StandardError => e
    log.kv 'controller_file', controller_file
    log.exception(e, style: :short)
    {}
  end
end
