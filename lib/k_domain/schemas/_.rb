# frozen_string_literal: true

# log.warn 'models->domain' if AppDebug.require?

module Types
  include Dry.Types()
end

require_relative 'investigate'
require_relative 'database/_'
require_relative 'domain/_'

require_relative './domain_model'

# require_relative './dictionary'
# require_relative './models/column'
# require_relative './models/model'
# require_relative './erd_file'
# require_relative './domain'
# require_relative './schema'

