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
        step.write(opts[:step_file])
        step.valid?
      end

      def guard(message)
        log.error message
        @valid = false
      end

      def write(file)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, JSON.pretty_generate(domain_data))
      end

      # Domain Model Accessor/Helpers
      def domain
        guard('domain is missing') if domain_data[:domain].nil?

        domain_data[:domain]
      end

      def domain_models
        domain[:models]
      end

      # Rails Resource File Accessor/Helpers
      def rails_resource
        guard('rails_resource is missing') if domain_data[:rails_resource].nil?

        domain_data[:rails_resource]
      end

      def rails_resource_models
        rails_resource[:models]
      end

      def rails_resource_models=(value)
        rails_resource[:models] = value
      end

      def rails_resource_controllers
        rails_resource[:controllers]
      end

      # Rails Structure File Accessor/Helpers
      def rails_structure
        guard('rails_structure is missing') if domain_data[:rails_structure].nil?

        domain_data[:rails_structure]
      end

      def rails_structure_models
        rails_structure[:models]
      end

      def rails_structure_models=(value)
        rails_structure[:models] = value
      end

      def rails_structure_controllers
        rails_structure[:controllers]
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
