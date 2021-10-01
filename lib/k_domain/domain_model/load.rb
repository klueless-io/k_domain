# frozen_string_literal: true

# Annotates the original schema with methods that implement existing method calls
# that are already in the schema so that we can build a hash.
#
# Writes a new annotated schema.rb file with a public method called load that
# builds the hash

module KDomain
  module DomainModel
    class Load
      include KLog::Logging

      attr_reader :source_file
      attr_reader :data

      def initialize(source_file)
        @source_file = source_file
      end

      def call
        json = File.read(source_file)
        data = KUtil.data.json_parse(json, as: :hash_symbolized)

        @data = KDomain::Schemas::DomainModel.new(data)
      end
    end
  end
end
