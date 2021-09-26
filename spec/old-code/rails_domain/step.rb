# frozen_string_literal: true

log.warn snake.parse('RailsDomainActions-Step3AttachColumns') if AppDebug.require?

# Attach columns to models
module RailsDomain
  class Step < BaseStep
    attr_writer :domain_data

    # Root data
    def domain_data
      guard('domain_data is missing') if @domain_data.nil?
      @domain_data
    end

    # Domain Model Accessor/Helpers
    def domain
      return @domain if defined? @domain

      @domain = begin
        guard('domain is missing') if domain_data[:domain].nil?
  
        domain_data[:domain]
      end      
    end
    
    def domain_models
      domain[:models]
    end

    # def erd_files
    #   return @erd_files if defined? @erd_files

    #   @erd_files = begin
    #     guard('erd_files is missing') if domain[:erd_files].nil?
  
    #     domain[:erd_files]
    #   end      
    # end

    # def erd_files_files
    #   erd_files[:files]
    # end

    # Database Accessor/Helpers
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
      database_tables.find { |table| table[:name] == model[:table_name]}
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

      return if investigation_hash.key?(unique_key)

      value = { step: step, location: location, key: key, message: message }

      investigations << value                   # list
      investigation_hash[unique_key] = value    # lookup
    end

    def investigations
      domain_data[:investigate][:investigations]
    end

    private

    def database_table_name_hash
      @database_table_name_hash ||= database_tables.to_h { |table| [table[:name], table[:name]] }
    end

    def build_key(*values)
      values.join('-')
    end

    def investigation_hash
      return @investigation_hash if defined? @investigation_hash

      @investigation_hash = begin
        investigations.to_h do |investigation|
          unique_key = build_key(investigation[:step], investigation[:location], investigation[:key])
          [unique_key, investigation]
        end
      end      
    end
  end
end