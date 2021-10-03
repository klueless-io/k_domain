# frozen_string_literal: true

# Takes a Rails Model and extracts DSL behaviours and custom functions (instance, class and private methods)
module KDomain
  module RailsCodeExtractor
    class ExtractModel
      include KLog::Logging

      attr_reader :source_file
      attr_reader :data

      def initialize(source_file)
        @source_file = source_file
      end

      def call
        log.kv 'source_file', source_file
      end
    end
  end
end
