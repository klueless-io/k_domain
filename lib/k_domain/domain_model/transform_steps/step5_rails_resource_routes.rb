# frozen_string_literal: true

# Locate rails model files
class Step5RailsResourceRoutes < KDomain::DomainModel::Step
  def call
    return warning('Routes .json file not supplied') if opts[:route_path].nil?
    return warning('Routes .json file not found') unless File.exist?(opts[:route_path])

    warning('Controller path not supplied. Routes will be loaded but not paired with a controller') if opts[:controller_path].nil?

    self.rails_resource_routes = load_routes(opts[:route_path], opts[:controller_path])
  end

  private

  def load_routes(route_path, controller_path)
    json = File.read(route_path)
    root = JSON.parse(json, symbolize_names: true)
    routes = root[:routes]

    routes.map { |route| map_route(route, controller_path) }
  end

  def map_route(route, controller_path)
    return route.merge({ file: '', exist: false }) if controller_path.nil?

    controller_file = File.join(controller_path, route[:controller_file])

    route.merge(
      {
        file: controller_file,
        exist: File.exist?(controller_file)
      }
    )
  end
end
