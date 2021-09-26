class MainKey
  class << self
    def lookup(entity_name, columns)
      config = DomainConfig.lookup(entity_name)

      return config.main_key if config.main_key

      # fallback main keys
      return :name          if columns.any? { |c| c.name.to_sym == :name }
      return :category      if columns.any? { |c| c.name.to_sym == :category }
      return :description   if columns.any? { |c| c.name.to_sym == :description }
      return :global        if columns.any? { |c| c.name.to_sym == :global }
      return :key           if columns.any? { |c| c.name.to_sym == :key }
      return :klass         if columns.any? { |c| c.name.to_sym == :klass }
      return :message       if columns.any? { |c| c.name.to_sym == :message }
      return :lead_source   if columns.any? { |c| c.name.to_sym == :lead_source }
      return :body          if columns.any? { |c| c.name.to_sym == :body }
      return :status        if columns.any? { |c| c.name.to_sym == :status }
      return :subject       if columns.any? { |c| c.name.to_sym == :subject }

      nil
    end
  end
end
