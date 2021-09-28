# frozen_string_literal: true

module KDomain
  module DomainModel
    class Step
      include KLog::Logging

      attr_reader :domain_data
      attr_reader :opts
      attr_reader :valid
      alias valid? valid

      def initialize(domain_data, **opts)
        # Useful for debugging
        # log.info "Initialize #{self.class.name}"

        @domain_data  = domain_data
        @opts         = opts
        @valid        = true
      end

      def call; end

      def self.run(domain_data, **opts)
        step = new(domain_data, **opts)
        step.call
        step
      end

      def guard(message)
        log.error message
        @valid = false
      end

      # Domain Model Accessor/Helpers
      def domain
        guard('domain is missing') if domain_data[:domain].nil?

        domain_data[:domain]
      end

      def domain_models
        domain[:models]
      end

      # Database Accessor/Helpers
      def database=(value)
        domain_data[:database] = value
      end

      def database
        guard('database is missing') if domain_data[:database].nil?

        domain_data[:database]
      end

      def database_tables
        guard('database_tables is missing') if database[:tables].nil?

        database[:tables]
      end

      def database_foreign_keys
        guard('database_foreign_keys is missing') if database[:foreign_keys].nil?

        database[:foreign_keys]
      end

      def find_table_for_model(model)
        database_tables.find { |table| table[:name] == model[:table_name] }
      end

      def table_name_exist?(table_name)
        if table_name.nil?
          guard('table_name_exist? was provided with a table_name: nil')
          return false
        end
        database_table_name_hash.key?(table_name)
      end

      def find_foreign_table(lhs_table_name, column_name)
        fk = database_foreign_keys.find { |foreign_key| foreign_key[:left] == lhs_table_name && foreign_key[:column] == column_name }
        return fk[:right] if fk

        nil
      end

      def investigate(step:, location:, key:, message:)
        unique_key = build_key(step, location, key)

        return if issue_hash.key?(unique_key)

        value = { step: step, location: location, key: key, message: message }

        issues << value                   # list
        issue_hash[unique_key] = value    # lookup
      end

      def issues
        domain_data[:investigate][:issues]
      end

      private

      def database_table_name_hash
        @database_table_name_hash ||= database_tables.to_h { |table| [table[:name], table[:name]] }
      end

      def build_key(*values)
        values.join('-')
      end

      def issue_hash
        return @issue_hash if defined? @issue_hash

        @issue_hash = issues.to_h do |issue|
          unique_key = build_key(issue[:step], issue[:location], issue[:key])
          [unique_key, issue]
        end
      end
    end
  end
end
