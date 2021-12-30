# frozen_string_literal: true

# Annotates the original schema with methods that implement existing method calls
# that are already in the schema so that we can build a hash.
#
# Writes a new annotated schema.rb file with a public method called load that
# builds the hash
module KDomain
  module RawDbSchema
    class Transform
      include KLog::Logging

      attr_reader :source_file
      attr_accessor :template_file
      attr_reader :schema_loader

      def initialize(source_file)
        @source_file = source_file
        @template_file = KDomain::Gem.resource('templates/load_schema.rb')
      end

      def call
        # log.kv 'source_file', source_file
        # log.kv 'template_file', template_file
        # log.kv 'source_file?', File.exist?(source_file)
        # log.kv 'template_file?', File.exist?(template_file)

        log.error "Template not found: #{template_file}" unless File.exist?(template_file)

        content = File.read(source_file)
        content
          .gsub!(/ActiveRecord::Schema.define/, 'load')

        lines = content.lines.map { |line| "    #{line}" }.join

        @schema_loader = File
                         .read(template_file)
                         .gsub('{{source_file}}', source_file)
                         .gsub('{{rails_schema}}', lines)
      end

      # rename to target_ruby
      # This is an internal ruby structure that is evaluated
      # writing is only needed for debugging purposes
      def write_schema_loader(target_file)
        if schema_loader.nil?
          puts '.call method has not been executed'
          return
        end

        FileUtils.mkdir_p(File.dirname(target_file))
        File.write(target_file, schema_loader)
      end

      def write_json(json_file)
        if schema_loader.nil?
          puts '.call method has not been executed'
          return
        end

        FileUtils.mkdir_p(File.dirname(json_file))
        File.write(json_file, JSON.pretty_generate(schema))
      end

      # rubocop:disable Security/Eval
      def schema
        if schema_loader.nil?
          puts '.call method has not been executed'
          return
        end

        eval(schema_loader) # , __FILE__, __LINE__)

        loader = LoadSchema.new
        loader.load_schema
        loader.schema
      rescue StandardError => e
        log.exception(e)
      end
      # rubocop:enable Security/Eval
    end
  end
end
