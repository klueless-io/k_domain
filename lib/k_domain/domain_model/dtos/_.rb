# frozen_string_literal: true

# log.warn 'models->domain' if AppDebug.require?

require_relative './dictionary/dictionary'
require_relative './investigate/issue'
require_relative './investigate/investigate'
require_relative './models/column'
require_relative './models/model'
require_relative './erd/erd_file_source'
require_relative './erd/erd_file'
require_relative './domain'
require_relative './schema'

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
