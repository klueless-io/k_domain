# frozen_string_literal: true

# log.warn 'models->domain' if AppDebug.require?

module Types
  include Dry.Types()
end

require_relative 'rails_resource'
require_relative 'rails_structure'
require_relative 'investigate'
require_relative 'database'
require_relative 'dictionary'
require_relative 'domain_types'
require_relative 'domain'
require_relative 'domain_model'

# require_relative './domain_model'
