# frozen_string_literal: true

require 'k_log'
require 'dry-struct'
require 'k_domain/version'
require 'k_domain/raw_db_schema/models/_'
require 'k_domain/raw_db_schema/transform'
require 'k_domain/raw_db_schema/load'
require 'k_domain/domain_model/transform'
require 'k_domain/domain_model/transform_steps/step'
require 'k_domain/domain_model/transform_steps/step1_attach_db_schema'
require 'k_domain/domain_model/transform_steps/step2_attach_models'

# # This is useful if you want to initialize structures via Hash
# class SymbolizeStruct < Dry::Struct
#   transform_keys(&:to_sym)
# end


module KDomain
  # raise KDomain::Error, 'Sample message'
  class Error < StandardError; end

  # Your code goes here...
end

if ENV['KLUE_DEBUG']&.to_s&.downcase == 'true'
  namespace = 'KDomain::Version'
  file_path = $LOADED_FEATURES.find { |f| f.include?('k_domain/version') }
  version = KDomain::VERSION.ljust(9)
  puts "#{namespace.ljust(35)} : #{version.ljust(9)} : #{file_path}"
end
