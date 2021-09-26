# log.warn snake.parse('RailsModelSchemaActions-BuildDomainModel') if AppDebug.require?

# class BuildDomainModel
#   attr_reader :context
#   attr_reader :domain

#   def initialize(context)
#     @context = context
#   end

#   def run
#     log.section_heading 'BuildDomainModel.run'

#     @domain = Domain.new(:printspeak)

#     map_entities

#     # sync_old_source_code

#     # map_entities_to_rails_models
#     # attach_ruby_code_to_rails_models

#     # builder
#     #   .add_file(target_schema_file,
#     #     template_file: 'load_schema.rb',
#     #     rails_schema: lines.join,
#     #     source_file: source_schema_file)
#   end

#   def map_entities
#     @domain.entities = context.rails_models.map { |model| map_entity(model) }
#   end

#   def map_entity(rails_model)
#     entity = Entity.new

#     #  if rails_model.name.nil? || rails_model.name == ''
#     entity.name           = rails_model.name
#     entity.name_plural    = rails_model.name_plural

#     entity.id             = rails_model.id
#     entity.force          = rails_model.force

#     # This entity has a main field that is useful for rendering and may be used for unique constraint, may also be called display_name
#     # entity.main_key       = map_main_key(map_to.name, map_from[:data_columns])

#     entity
#   end

#   # def attach_ruby_code(model)
#   #   return unless model.exists?
#   #   print '.'
#   # end
# end
