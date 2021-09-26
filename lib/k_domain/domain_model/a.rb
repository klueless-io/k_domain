# Annotates the original schema with methods that implement existing method calls
# that are already in the schema so that we can build a hash.
#
# Writes a new annotated schema.rb file with a public method called load that
# builds the hash
# frozen_string_literal: true

module KDomain
  module DomainModel
    class A
      include KLog::Logging

      # attr_reader :source_file
    
      # def initialize(source_file)#, target_file)
      #   @source_file = source_file
      #   @template_file = 'lib/k_domain/raw_db_schema/template.rb'
      # end
 
      def call
        # log.kv 'source_file', source_file
      end
    end
  end
end
