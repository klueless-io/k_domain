# Annotates the original schema with methods that implement existing method calls
# that are already in the schema so that we can build a hash.
#
# Writes a new annotated schema.rb file with a public method called load that
# builds the hash
# frozen_string_literal: true

module KDomain
  module RawDbSchema
    class Transform
      include KLog::Logging

      attr_reader :source_file
      attr_reader :template_file
      attr_reader :target_ruby_class
    
      def initialize(source_file)#, target_file)
        @source_file = source_file
        @template_file = 'lib/k_domain/raw_db_schema/template.rb'
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

        lines = content.lines.map { |line| "    #{line}" }.join()

        @target_ruby_class = File
          .read(template_file)
          .gsub('{{source_file}}', source_file)
          .gsub('{{rails_schema}}', lines)
      end

      def write_target(target_file)
        if target_ruby_class.nil?
          puts '.call method has not been executed'
          return
        end

        FileUtils.mkdir_p(File.dirname(target_file))
        File.write(target_file, target_ruby_class)
      end

      def json
        if target_ruby_class.nil?
          puts '.call method has not been executed'
          return
        end

        # load target_file
        eval target_ruby_class
    
        loader = LoadSchema.new
        loader.load_schema()
        loader.schema
      end
    end
  end
end
