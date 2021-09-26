class Traits
  class << self
    def lookup(entity_name)
      config = DomainConfig.lookup(entity_name)

      return config.traits if config.traits

      []
    end
  end
end
