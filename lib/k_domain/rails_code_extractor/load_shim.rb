# frozen_string_literal: true

# Code extraction requires shims to be loaded before extraction
#
# This shims server two purposes
#
# 1. Inject data capture methods calls that intercept DSL macros so that data can be extracted
# 2. Inject fake module/classes that would otherwise break code loading with various exceptions
module KDomain
  module RailsCodeExtractor
    class LoadShim
      include KLog::Logging

      attr_reader :shim_files

      attr_reader :dsl_shim_file
      attr_reader :fake_module_file

      def initialize
        @shim_files = []
      end

      def call
        log.kv 'preload', preload
      end

      def register(name, file)
        @shim_files << { name: name, file: file, exist: File.exist?(file) }
      end
    end
  end
end
