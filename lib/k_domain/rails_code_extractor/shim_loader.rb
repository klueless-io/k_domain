# frozen_string_literal: true

# Code extraction requires shims to be loaded before extraction
#
# This shims server two purposes
#
# 1. Inject data capture methods calls that intercept DSL macros so that data can be extracted
# 2. Inject fake module/classes that would otherwise break code loading with various exceptions
module KDomain
  module RailsCodeExtractor
    class ShimLoader
      include KLog::Logging

      attr_reader :shim_files

      def initialize
        @shim_files = []
      end

      def call
        shim_files.select { |sf| sf[:exist] }.each { |sf| require sf[:file] }
      end

      def register(name, file)
        @shim_files << { name: name, file: file, exist: File.exist?(file) }
      end
    end
  end
end
