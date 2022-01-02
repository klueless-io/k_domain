KManager.action do
  def on_action
    puts '-' * 70
    builder.cd(:lib_config)
    director = ConfigurationDirector
      .init(builder, on_exist: :compare)
      .style(:single)
      .name('Domain Configuration')
      .main_namespace('KDomain', 'Config')
      .add_config_key(:default_main_key, "nil")
      .add_config_key(:default_traits, "%i[trait1 trait2 trait3]")
      .add_config_key(:fallback_keys, "%i[]")
      .add_config_key(:entities, "[]")
      # .logit

    # dom = director.dom
    # data = director.data

    director.add_config
    # director.add_configuration
  end
end