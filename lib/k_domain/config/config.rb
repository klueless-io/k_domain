# frozen_string_literal: true

# Usage: include KDomain::Config::

module KDomain
  module Config
    def configuration
      @configuration ||= KDomain::Config::Configuration.new
    end

    def reset
      @configuration = KDomain::Config::Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
