# frozen_string_literal: true

module KDomain
  module Queries
    # Query models found on the domain model
    # by
    #   has ruby file
    #   has primary key
    #   column count
    #   data column count
    #   foreign key column count
    #   has timestamp (created_at, updated_at) columns
    #   has created_at
    #   has updated_at
    #   has deleted_at
    #   has polymorphic foreign keys
    #   has virtual columns
    #   virtual column filters (token, encrypted_password, etc)
    class DomainModelQuery < BaseQuery
      def all
        domain_model.domain.models
      end

      def query(**filters)
        @query = all.clone

        filters.each do |key, value|
          send("filter_#{key}", value)
        end

        @query
      end

      private

      def filter_ruby(value)
        @query.select! { |model| model.ruby? == value }
      end

      def filter_pk(value)
        @query.select! { |model| model.pk.exist? == value }
      end

      def filter_column_count(block)
        @query.select! { |model| block.call(model.columns.count) }
      end

      def filter_data_column_count(block)
        @query.select! { |model| block.call(model.columns_data.count) }
      end

      def filter_foreign_key_column_count(block)
        @query.select! { |model| block.call(model.columns_foreign_key.count) }
      end
      alias filter_fk_column_count filter_foreign_key_column_count
      alias filter_fk_count filter_foreign_key_column_count

      def filter_polymorphic_foreign_key_column_count(block)
        @query.select! { |model| block.call(model.columns_foreign_type.count) }
      end
      alias filter_poly_fk_column_count filter_polymorphic_foreign_key_column_count
      alias filter_poly_fk_count filter_polymorphic_foreign_key_column_count

      def filter_timestamp(value)
        @query.select! { |model| (model.columns_timestamp.count == 2) == value }
      end

      def filter_created_at(value)
        @query.select! { |model| (model.columns.any? { |column| column.name == 'created_at' } == value) }
      end

      def filter_updated_at(value)
        @query.select! { |model| (model.columns.any? { |column| column.name == 'updated_at' } == value) }
      end

      def filter_deleted_at(value)
        @query.select! { |model| (model.columns.any? { |column| column.name == 'deleted_at' } == value) }
      end
      #   has virtual columns
      #   virtual column filters (token, encrypted_password, etc)

      # # HELP: this filter affects table rows, eg. if a table has less the 2 columns then include the table
      # low_column:           -> (model) { model.columns.length < 5 },
      # suspected_m2m:       -> (model) { model.columns_foreign.length == 2 && model.columns_data.length < 3 },
      # invalid_types:        -> (model) { model.columns.any? { |c| [c.db_type, c.csharp_type, c.ruby_type].include?('******') } },
    end
  end
end
