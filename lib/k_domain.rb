# frozen_string_literal: true

require 'active_support/core_ext/string'
require 'dry-struct'
require 'k_log'
require 'peeky'
require 'k_domain/version'
require 'k_domain/config/_'
require 'k_domain/schemas/_'
require 'k_domain/raw_db_schema/transform'
require 'k_domain/raw_db_schema/load'
require 'k_domain/domain_model/transform'
require 'k_domain/domain_model/transform_steps/_'
require 'k_domain/domain_model/load'
require 'k_domain/rails_code_extractor/_'
require 'k_domain/queries/_'

# # This is useful if you want to initialize structures via Hash
# class SymbolizeStruct < Dry::Struct
#   transform_keys(&:to_sym)
# end

module KDomain
  extend KDomain::Config

  # raise KDomain::Error, 'Sample message'
  class Error < StandardError; end

  module Gem
    def self.root
      File.expand_path('..', File.dirname(__FILE__))
    end

    def self.resource(resource_path)
      File.join(root, resource_path)
    end
  end

  # Your code goes here...
end

if ENV.fetch('KLUE_DEBUG', 'false').downcase == 'true'
  namespace = 'KDomain::Version'
  file_path = $LOADED_FEATURES.find { |f| f.include?('k_domain/version') }
  version = KDomain::VERSION.ljust(9)
  puts "#{namespace.ljust(35)} : #{version.ljust(9)} : #{file_path}"
end
