# frozen_string_literal: true

# Takes a Rails controller and extracts DSL behaviours and custom functions (instance, class and private methods)
module KDomain
  module RailsCodeExtractor
    class ExtractController
      include KLog::Logging

      attr_reader :shims_loaded
      attr_reader :controller

      def initialize(load_shim)
        @load_shim = load_shim
        @shims_loaded = false
      end

      def extract(file)
        load_shims unless shims_loaded

        ActionController.class_info = nil
        # KDomain::RailsCodeExtractor.reset

        load_retry(file, 10, nil)
      rescue StandardError => e
        log.exception(e)
      end

      private

      def load_shims
        @load_shim.call
        @shims_loaded = true
      end

      # rubocop:disable Security/Eval,Style/EvalWithLocation,Style/DocumentDynamicEvalDefinition,Metrics/AbcSize
      def load_retry(file, times, last_error)
        return if times.negative?

        # puts file
        load(file)

        @controller = ActionController::Base::class_info
        # @controller = KDomain::RailsCodeExtractor.class_info

        # get_method_info(File.base_name(file))
      rescue StandardError => e
        log.kv 'times', times
        # puts e.message
        if e.is_a?(NameError) && e.message != last_error&.message
          log.kv('add module', e.name)
          eval("module #{e.name}; end")
          return load_retry(file, times - 1, e)
        end
        log.exception(e, short: true, method_info: method(__callee__))
      end
      # rubocop:enable Security/Eval,Style/EvalWithLocation,Style/DocumentDynamicEvalDefinition,Metrics/AbcSize
    end
  end
end
