# frozen_string_literal: true

module KDomain
  module DomainModel
    class ColumnOld
      # DONE
      RUBY_TYPE = {
        string: 'String',
        text: 'String',
        primary_key: 'Integer', # this could be GUID in future
        foreign_key: 'Integer', # this could be GUID in future
        integer: 'Integer',
        boolean: 'Boolean',
        float: 'Float',
        decimal: 'Decimal',
        datetime: 'DateTime',
        date: 'DateTime',
        json: 'Hash',
        jsonb: 'Hash',
        hstore: 'Hash'
      }.freeze

      # DONE
      CSHARP_TYPE = {
        string: 'string',
        text: 'string', # NEED TO DEAL WITH THIS BETTER
        integer: 'int',
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
      # DONE
      DB_TYPE = {
        boolean: 'boolean',
        primary_key: 'integer',
        foreign_key: 'integer',
        integer: 'integer',
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

      SIMPLE_ATTRIBS = %i[
        name
        name_plural
        type
        structure_type
        foreign_key?
        foreign_table
        foreign_id
      ].freeze

      DETAILED_ATTRIBS = SIMPLE_ATTRIBS + %i[
        title
        required
        reference_type
        db_type
        ruby_type
        csharp_type
        format_type
        description
        belongs_to
      ]

      EXTRA_ATTRIBS = DETAILED_ATTRIBS + %i[
        precision
        scale
        default
        null
        limit
        array
      ]

      # Name of the column
      attr_accessor :name

      # Name of the column in plural form
      attr_accessor :name_plural

      attr_accessor :type

      # Human readable title
      attr_accessor :title

      # true
      attr_accessor :required

      attr_accessor :structure_type # :data, :foreign_key, :timestamp
      attr_accessor :reference_type

      # 'references' if foreign key, 'primary_key' if primary key, will map_from_type(type)) |
      # attr_accessor :db_type

      attr_accessor :format_type
      attr_accessor :description

      attr_accessor :foreign_key
      alias foreign_key? foreign_key
      attr_accessor :foreign_table
      attr_accessor :belongs_to
      # this may not always be accurate, should support override
      attr_accessor :foreign_id
      alias reference_table foreign_id

      # Extra DB attributes
      attr_accessor :precision
      attr_accessor :scale
      attr_accessor :default
      attr_accessor :null
      alias nullable null
      attr_accessor :limit
      attr_accessor :array

      def format_default
        return '' if default.nil?
        return "\"#{default}\"" if default.is_a?(String)

        #  || default.is_a?(Symbol)
        default.to_s
      end

      def format_null
        null.nil? ? '' : null.to_s
      end

      def format_array
        array.nil? ? '' : array.to_s
      end

      # DONE
      def db_type
        return @db_type if defined? @db_type

        @db_type = DB_TYPE[type] || '******'
      end

      # DONE
      def ruby_type
        return @ruby_type if defined? @ruby_type

        @ruby_type = RUBY_TYPE[type] || '******'
      end

      # DONE
      def csharp_type
        return @csharp_type if defined? @csharp_type

        @csharp_type = CSHARP_TYPE[type] || '******'
      end

      def debug(*flags)
        debug_simple    if flags.include?(:simple)
        debug_detailed  if flags.include?(:detailed)
        debug_extra     if flags.include?(:extra)
      end

      private

      def debug_simple
        log.kv 'name'             , name
        log.kv 'name_plural'      , name_plural
        log.kv 'type'             , type
        log.kv 'structure_type'   , structure_type
      end

      def debug_detailed
        debug_simple
        log.kv 'title'            , title
        log.kv 'required'         , required
        log.kv 'reference_type'   , reference_type
        log.kv 'db_type'          , db_type
        log.kv 'ruby_type'        , ruby_type
        log.kv 'csharp_type'      , csharp_type
        log.kv 'format_type'      , format_type
        log.kv 'description'      , description

        log.kv 'foreign_key?'     , foreign_key?
        log.kv 'foreign_table'    , foreign_table
        log.kv 'belongs_to'       , belongs_to
        log.kv 'foreign_id'       , foreign_id
      end

      def debug_extra
        debug_detailed

        log.kv 'precision'        , precision
        log.kv 'scale'            , scale
        log.kv 'default'          , default
        log.kv 'null'             , null
        log.kv 'limit'            , limit
        log.kv 'array'            , array
      end
    end

    # ---------------------------------------------
    # Available column keys that can be mapped from
    # ---------------------------------------------
    # name
    # name_plural
    # type
    # foreign_key?
    # foreign_table
    # structure_type
    # precision
    # scale
    # default
    # null
    # limit
    # array
    # belongs_to
  end
end
