# frozen_string_literal: true

require 'k_log'
require 'k_domain/version'
require 'k_domain/raw_db_schema/transform'

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
