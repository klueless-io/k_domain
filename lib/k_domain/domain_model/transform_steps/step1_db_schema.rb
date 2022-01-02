# frozen_string_literal: true

module KDomain
  module DomainModel
    class Step1DbSchema < KDomain::DomainModel::Step
      # Map database schema to domain model
      def call
        raise 'Schema not supplied' if opts[:db_schema].nil?

        self.database = opts[:db_schema].clone
        database[:tables] = database[:tables] # .take(10) # .slice(156, 1)

        guard('tables are missing')               if database[:tables].nil?
        guard('indexes are missing')              if database[:indexes].nil?
        guard('foreign keys are missing')         if database[:foreign_keys].nil?
        guard('rails version is missing')         if database[:meta][:rails].nil?
        guard('postgres extensions are missing')  if database[:meta][:db_info][:extensions].nil?
        guard('unique keys are missing')          if database[:meta][:unique_keys].nil?
      end
    end
  end
end
