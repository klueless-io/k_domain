# frozen_string_literal: true

# log.warn 'models->domain' if AppDebug.require?

require_relative './dictionary/dictionary'
require_relative './investigate/issue'
require_relative './investigate/investigate'
require_relative './models/column'
require_relative './models/model'
require_relative './domain'
require_relative './schema'

# require_relative './helper/domain_config'
# require_relative './helper/main_key'
# require_relative './helper/traits'

# require_relative './belongs_to'
# require_relative './domain_statistics'
# # require_relative './domain_mapper'
# require_relative './entity'
# require_relative './entity_statistics'
# require_relative './foreign_key'
# require_relative './has_and_belongs_to_many'
# require_relative './has_many'
# require_relative './has_one'
# require_relative './name_options'
# require_relative './rails_model'
# require_relative './related_entity'
# require_relative './statistics'
# require_relative './validate'
# require_relative './validates'

module KDomain
  module DomainModel
    RUBY_TYPE = {
      text: 'String',
      string: 'String',
      primary_key: 'Integer', # this could be GUID in future
      foreign_key: 'Integer', # this could be GUID in future
      integer: 'Integer',
      bigint: 'Integer',
      bigserial: 'Integer',
      boolean: 'Boolean',
      float: 'Float',
      decimal: 'Decimal',
      datetime: 'DateTime',
      date: 'DateTime',
      json: 'Hash',
      jsonb: 'Hash',
      hstore: 'Hash'
    }.freeze

    CSHARP_TYPE = {
      string: 'string',
      text: 'string', # NEED TO DEAL WITH THIS BETTER
      integer: 'int',
      bigint: 'int',
      bigserial: 'long',
      boolean: 'bool',
      decimal: 'decimal',
      float: 'double',
      datetime: 'DateTime',
      date: 'DateTime',
      json: 'object',
      jsonb: 'object',
      hstore: 'object'
    }.freeze

    # this is used by the ruby migration files
    DB_TYPE = {
      boolean: 'boolean',
      primary_key: 'integer',
      foreign_key: 'integer',
      integer: 'integer',
      bigint: 'integer',
      bigserial: 'bigserial',
      decimal: 'decimal',
      float: 'float',
      datetime: 'datetime',
      date: 'date',
      text: 'text',
      string: 'string',
      json: 'json',
      jsonb: 'jsonb',
      hstore: 'hstore'
    }.freeze
  end
end
