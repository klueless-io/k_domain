# Boot Sequence

include KLog::Logging

CONFIG_KEY = :k_domain

log.kv 'working folder', Dir.pwd

Handlebars::Helpers.configure do |config|
  config_file = File.join(Gem.loaded_specs['handlebars-helpers'].full_gem_path, '.handlebars_helpers.json')
  config.helper_config_file = config_file

  string_config_file = File.join(Gem.loaded_specs['handlebars-helpers'].full_gem_path, '.handlebars_string_formatters.json')
  config.string_formatter_config_file = string_config_file
end

def builder
  @builder ||= KBuilder::BaseBuilder.init(KBuilder.configuration(CONFIG_KEY))
end

KBuilder.configure(CONFIG_KEY) do |config|
  global_template = File.expand_path('~/dev/kgems/k_templates/templates')
  config.target_folders.add(:app, File.expand_path('../', Dir.pwd))
  config.target_folders.add(:lib_config, :app, 'lib/k_domain/config')
  config.template_folders.add(:global_template, global_template)
  config.template_folders.add(:app_template, File.expand_path('.templates', Dir.pwd))
end

KBuilder.configuration(CONFIG_KEY).debug

area = KManager.add_area(CONFIG_KEY)
resource_manager = area.resource_manager
resource_manager.add_resource('https://raw.githubusercontent.com/klueless-io/k_playground/main/ruby/components/configuration/.builders/configuration_director.rb', content_type: :ruby)
resource_manager
  .fileset
  .glob('*.rb', exclude: ['boot.rb'])
  .glob('generators/**/*.rb')
resource_manager.add_resources

KManager.fire_actions(:load_content, :register_document, :load_document)
