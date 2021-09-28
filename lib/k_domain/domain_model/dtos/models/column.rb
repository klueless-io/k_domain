# frozen_string_literal: true

module KDomain
  module DomainModel
    class Column < Dry::Struct
      attribute :name                 , Types::Strict::String                         #  "source_account_id"
      attribute :name_plural          , Types::Strict::String                         #  "source_account_ids"
      attribute :type                 , Types::Coercible::Symbol                      #  "integer"
      attribute :precision            , Types::Strict::Integer.optional.default(nil)  #  null
      attribute :scale                , Types::Strict::Integer.optional.default(nil)  #  null
      attribute :default              , Types::Nominal::Any.optional.default(nil)     #  null
      attribute :null                 , Types::Nominal::Any.optional.default(nil)     #  null
      attribute :limit                , Types::Strict::Integer.optional.default(nil)  #  null
      attribute :array                , Types::Strict::Bool.optional.default(nil)     #  null

      # Calculated value
      attribute :structure_type       , Types::Coercible::Symbol                      #
      attribute :foreign_key          , Types::Strict::Bool.optional.default(nil)     #
      attribute :foreign_table        , Types::Strict::String                         #
      attribute :foreign_table_plural , Types::Strict::String                         #

      # def data_column
      #   @columns_data ||= structure_type?(:data)
      # end

      # def structure_type?(*structure_types)
      #   structure_types.include?(column.structure_type)
      # end

      def db_type
        return @db_type if defined? @db_type

        @db_type = DB_TYPE[type] || '******'
      end

      def ruby_type
        return @ruby_type if defined? @ruby_type

        @ruby_type = RUBY_TYPE[type] || '******'
      end

      def csharp_type
        return @csharp_type if defined? @csharp_type

        @csharp_type = CSHARP_TYPE[type] || '******'
      end
    end
  end
end
