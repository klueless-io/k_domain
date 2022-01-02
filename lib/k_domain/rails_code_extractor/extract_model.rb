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

        ActiveRecord.class_info = nil

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

        load(file)

        @model = ActiveRecord.class_info

        if @model.nil?
          # puts ''
          # puts file
          # puts 'class probably has no DSL methods'
          @model = {
            class_name: File.basename(file, File.extname(file)).classify
          }
        end

        @models << @model

        # get_method_info(File.base_name(file))
      rescue StandardError => e
        log.kv 'times', times
        # puts e.message
        if e.is_a?(NameError) && e.message != last_error&.message
          log.kv('add module', e.name)
          log.kv 'file', file
          eval("module #{e.name}; end")
          return load_retry(file, times - 1, e)
        end
        log.kv 'file', file
        log.exception(e, style: :short, method_info: method(__callee__))
      end
      # rubocop:enable Security/Eval,Style/EvalWithLocation,Style/DocumentDynamicEvalDefinition,Metrics/AbcSize
    end
  end
end
