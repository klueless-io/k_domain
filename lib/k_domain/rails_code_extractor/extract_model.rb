# frozen_string_literal: true

# Takes a Rails Model and extracts DSL behaviours and custom functions (instance, class and private methods)
module KDomain
  module RailsCodeExtractor
    class ExtractModel
      include KLog::Logging

      attr_reader :shims_loaded
      attr_reader :models
      attr_reader :model

      def initialize(load_shim)
        @load_shim = load_shim
        @shims_loaded = false
        @models = []
      end

      def extract(file)
        load_shims unless shims_loaded

        ActiveRecord.current_class = nil

        load_retry(file, 10)
      rescue StandardError => e
        log.exception(e)
      end

      private

      def load_shims
        @load_shim.call
        @shims_loaded = true
      end

      # rubocop:disable Security/Eval,Style/EvalWithLocation,Style/DocumentDynamicEvalDefinition,Metrics/AbcSize
      def load_retry(file, times)
        return if times.negative?

        load(file)

        @model = ActiveRecord.current_class
        @models << @model

        # get_method_info(File.base_name(file))
      rescue StandardError => e
        puts e.message
        if e.is_a?(NameError)
          log.kv('add module', e.name)
          eval("module #{e.name}; end")
          return load_retry(path, times - 1)
        end
        log.exception(e)
      end
      # rubocop:enable Security/Eval,Style/EvalWithLocation,Style/DocumentDynamicEvalDefinition,Metrics/AbcSize
    end
  end
end
