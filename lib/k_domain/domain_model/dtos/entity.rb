# frozen_string_literal: true

module KDomain
  module DomainModel
    class Entity
      # Name of the entity model
      attr_accessor :name

      # Name of the entity model in plural form
      attr_accessor :name_plural

      # @param [Symbol] value The value of ID has different meanings
      # @option value :true Id column exists and it uses an Integer type
      # @option value :false Id column does not exist
      # @option value :bigserial Id column exists and it uses a BigSerial type
      attr_accessor :id

      # Currently only has the value :cascade
      attr_accessor :force

      # Model columns
      attr_accessor :columns

      # Model relationships - one_to_one, one_to_many and many_to_many
      attr_accessor :relations_one_to_one

      # This entity has a main field that is useful for rendering and may be used for unique constraint, may also be called display_name
      attr_accessor :main_key

      attr_accessor :trait1
      attr_accessor :trait2
      attr_accessor :trait3

      # investigate
      attr_accessor :td_query

      # Model type - :entity, :basic_user, :admin_user
      attr_accessor :model_type

      attr_accessor :rails_model
      attr_accessor :statistics

      def key?
        !main_key.nil?
      end

      def no_key
        main_key.nil?
      end
      alias keyless? no_key

      # Can probably deprecate model_
      alias model_name           name
      alias names                name_plural

      alias td_key1              trait1
      alias td_key2              trait2
      alias td_key3              trait3

      # alias :name :student_name    # not wrong, only for getter
      # alias :name= :student_name=  # add this for setter
      # alias :name? :student_name?  # add this for boolean

      attr_accessor :belongs_to
      attr_accessor :has_one
      attr_accessor :has_many
      attr_accessor :has_and_belongs_to_many

      # Needs to move into RailsModel
      attr_accessor :validates
      attr_accessor :validate

      def relations?
        # log.kv 'has_one', has_one.length
        # log.kv 'has_many', has_many.length
        # log.kv 'has_and_belongs_to_many', has_and_belongs_to_many.length
        has_one.length.positive? || has_many.length.positive? || has_and_belongs_to_many.length.positive?
      end

      def initialize
        @columns = []
        @relations = []

        @belongs_to = []
        @has_one = []
        @has_many = []
        @has_and_belongs_to_many = []

        @rails_model = nil
        @statistics = nil
      end

      # Filter helpers
      def filter_columns(type_of_columns)
        case type_of_columns
        when :columns_data
          columns_data
        when :columns_data_optional
          columns_data_optional
        when :columns_data_required
          columns_data_required
        when :columns_data_foreign
          columns_data_foreign
        when :columns_primary
          columns_primary
        when :columns_foreign
          columns_foreign
        when :columns_virtual
          columns_virtual
        when :columns_data_foreign_virtual
          columns_data_foreign_virtual
        when :columns_data_primary
          columns_data_primary
        when :columns_data_virtual
          columns_data_virtual
        else
          columns
        end
      end

      def to_h
        {
          name: name,
          name_plural: name_plural,
          type: type,
          title: title,
          required: required,
          structure_type: structure_type,
          reference_type: reference_type,
          format_type: format_type,
          description: description,
          foreign_key: foreign_key,
          foreign_table: foreign_table,
          belongs_to: belongs_to,
          foreign_id: foreign_id,
          precision: precision,
          scale: scale,
          default: default,
          null: null,
          limit: limit,
          array: array
        }
      end

      # DONE
      def columns_data
        @columns_data ||= columns_for_structure_types(:data)
      end
      alias rows_fields columns_data

      # TODO
      def columns_data_optional
        @columns_data_optional ||= columns_for_structure_types(:data).select { |_c| true }
      end

      # TODO
      def columns_data_required
        @columns_data_required ||= columns_for_structure_types(:data).select { |_c| false }
      end

      # DONE
      def columns_primary
        @columns_primary ||= columns_for_structure_types(:primary_key)
      end

      # DONE
      def columns_foreign
        @columns_foreign ||= columns_for_structure_types(:foreign_key)
      end

      # DONE
      def columns_timestamp
        @columns_data_timestamp ||= columns_for_structure_types(:timestamp)
      end

      # DONE
      def columns_deleted_at
        @columns_data_deleted_at ||= columns_for_structure_types(:deleted_at)
      end

      # DONE
      def columns_virtual
        @columns_virtual ||= columns_for_structure_types(:timestamp, :deleted_at)
      end

      # DONE
      def columns_data_foreign
        @columns_data_foreign ||= columns_for_structure_types(:data, :foreign_key)
      end
      alias rows_fields_and_fk columns_data_foreign

      # DONE
      def columns_data_primary
        @columns_data_primary ||= columns_for_structure_types(:data, :primary_key)
      end
      alias rows_fields_and_pk columns_data_primary

      # DONE
      def columns_data_virtual
        @columns_data_virtual ||= columns_for_structure_types(:data, :timestamp, :deleted_at)
      end
      alias rows_fields_and_virtual columns_data_virtual

      # DONE
      def columns_data_foreign_virtual
        @columns_data_foreign_virtual ||= columns_for_structure_types(:data, :foreign_key, :timestamp, :deleted_at)
      end

      # DONE
      def columns_for_structure_types(*structure_types)
        columns.select { |column| structure_types.include?(column.structure_type) }
      end

      # Debug helpers

      def debug(*flags)
        debug_simple   if flags.include?(:simple)
        debug_detailed if flags.include?(:detailed)
        debug_extra    if flags.include?(:extra)

        debug_columns(*flags)
        debug_belongs_to(*flags)
        debug_has_one(*flags)
        debug_has_many(*flags)
        debug_has_and_belongs_to_many(*flags)
        # log.kv 'relations'    , relations
      end

      def debug_simple
        log.kv 'name'         , name
        log.kv 'name_plural'  , name_plural
        log.kv 'main_key'     , main_key
        log.kv 'model_type'   , model_type
      end

      def debug_detailed
        debug_simple
        log.kv 'id'           , id
        log.kv 'trait1'       , trait1
        log.kv 'trait2'       , trait2
        log.kv 'trait3'       , trait3
        log.kv 'td_query'     , td_query
        log.kv 'key?'         , key?
        log.kv 'no_key'       , no_key
      end

      def debug_extra
        debug_detailed
        log.kv 'force'        , force
      end

      def debug_columns(*flags, column_list: columns)
        c_simple            = flags.include?(:columns_simple)
        c_detailed          = flags.include?(:columns_detailed)
        c_extra             = flags.include?(:columns_extra)
        c_tabular           = flags.include?(:columns_tabular_simple) || flags.include?(:columns_tabular)
        c_tabular_detailed  = flags.include?(:columns_tabular_detailed)
        c_tabular_extra     = flags.include?(:columns_tabular_extra)

        return unless c_simple || c_detailed || c_extra || c_tabular || c_tabular_detailed || c_tabular_extra

        log.section_heading('columns')

        column_list.each { |column| column.debug(:simple) }   if c_simple
        column_list.each { |column| column.debug(:detailed) } if c_detailed
        column_list.each { |column| column.debug(:extra) }    if c_extra
        tp column_list, *Column::SIMPLE_ATTRIBS               if c_tabular
        tp column_list, *Column::DETAILED_ATTRIBS             if c_tabular_detailed
        tp column_list, *Column::EXTRA_ATTRIBS                if c_tabular_extra
      end

      def debug_belongs_to(*flags)
        c_simple = flags.include?(:belongs_to_tabular)

        return unless c_simple && belongs_to.length.positive?

        log.section_heading('belongs_to')

        tp belongs_to, :name, :model_name, :model_name_plural, *BelongsTo::KEYS
      end

      def debug_has_one(*flags)
        c_simple = flags.include?(:has_one_tabular)

        return unless c_simple && has_one.length.positive?

        log.section_heading('has_one')

        tp has_one, :name, :model_name, :model_name_plural, *HasOne::KEYS
      end

      def debug_has_many(*flags)
        c_simple = flags.include?(:has_many_tabular)

        return unless c_simple && has_many.length.positive?

        log.section_heading('has_many')

        tp has_many, :name, :model_name, :model_name_plural, *HasMany::KEYS
      end

      def debug_has_and_belongs_to_many(*flags)
        c_simple = flags.include?(:has_and_belongs_to_many_tabular)

        return unless c_simple && has_and_belongs_to_many.length.positive?

        log.section_heading('has_and_belongs_to_many')

        tp has_and_belongs_to_many, :name, :model_name, :model_name_plural, *HasAndBelongsToMany::KEYS
      end
    end
    # ---------------------------------------------
    # Available entity keys that can be mapped from
    # ---------------------------------------------
    # name
    # name_plural
    # id
    # force
    # created
    # updated
    # columns
    # data_columns
    # foreign_columns
    # belongs
    # has_one
    # has_many
    # has_and_belongs_to_many
    # class_methods
    # public_class_methods
    # private_class_methods
    # instance_methods
    # public_instance_methods
    # private_instance_methods
    # default_scope
    # scopes
    # meta
  end
end
