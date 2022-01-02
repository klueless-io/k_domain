# frozen_string_literal: true

module KDomain
  module Schemas
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
