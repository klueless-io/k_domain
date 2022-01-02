# frozen_string_literal: true

module KDomain
  module Config
    # Configuration object for Domain Configuration
    class Configuration
      include KLog::Logging

      ConfigModel = Struct.new(:name, :main_key, :traits)

      attr_accessor :default_main_key
      attr_accessor :default_traits
      attr_accessor :fallback_keys
      attr_accessor :models

      def initialize
        @default_main_key = nil
        @default_traits = %i[trait1 trait2 trait3]
        @fallback_keys = %i[]
        @models = []
      end

      def model(name, main_key: nil, traits: nil)
        @models << new_config_model(
          name,
          main_key: main_key || default_main_key,
          traits: traits || default_traits
        )
      end

      def find_model(table_name)
        @find_model ||= Hash.new do |h, key|
          h[key] = begin
            entity = models.find { |e| e.name == key }
            entity ||= new_config_model(key)
            entity
          end
        end

        @find_model[table_name]
      end

      def fallback_key(columns)
        column_names = columns.each_with_object({}) do |column, hash|
          hash[column.name.to_sym] = column.name.to_sym
        end

        fallback_keys.find { |key| column_names.key?(key) }
      end

      def debug(heading: 'Domain configuration')
        log.structure(to_h, title: heading) # , line_width: 150, formatter: formatter)
        ''
      end

      def to_h
        {
          default_main_key: default_main_key,
          default_traits: default_traits,
          fallback_keys: fallback_keys,
          models: models.map(&:to_h)
        }
      end

      private

      def new_config_model(name, main_key: nil, traits: nil)
        ConfigModel.new(
          name,
          main_key || default_main_key,
          traits || default_traits
        )
      end
    end
  end
end
