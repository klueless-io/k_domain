# Converts a table/entity object that has come directly from the database schema into
# a RailsModel that has information about the models/[table_name].rb file
#
# @param [Hash] table use a schema table object and convert it into a ModelReference
class TableToRailsModelMapper
  attr_reader :path_models
  attr_reader :documentation_rel_path_models

  def initialize
    @path_models = '/Users/davidcruwys/dev/printspeak/printspeak-master/app/models'
    # should be relative to markdown file
    @documentation_rel_path_models = '../../../../printspeak/app/models'
  end

  # @param [Hash] table use a schema table object and convert it into a ModelReference
  def map(table)
    @model = RailsModel.new

    # table names could be in either plural or singular format, this will normalize the issue
    
    @model.name_original  = table['name']
    @model.name           = singularize.parse(table['name'])
    @model.id             = table['id']
    binding.pry
    @model.force          = table['force']
    @model.primary_key    = table['primary_key']
  
    map_paths
    
    if @model.exists?
      @model.add_quirk :has_ruby_model
    else
      handle_custom_model_name
    end

    @model.name_plural  = pluralize.parse(@model.name)

    @model
  end

  private

  # Links the table to the rails model a maps real code location
  def map_paths
    @model.model_path = File.join(path_models, "#{@model.name}.rb")
    @model.documentation_rel_path = File.join(documentation_rel_path_models, "#{@model.name}.rb")
  end

  def handle_custom_model_name
    path = File.join(path_models, "#{@model.name_original}.rb")

    if File.exist?(path)
      @model.name                   = @model.name_original
      map_paths

      @model.add_quirk :nonconventional_name
    else
      # @model.name                 = ''
      @model.model_path             = ''
      @model.documentation_rel_path = ''

      @model.add_quirk :m2m_table
    end

    # log.error @model.name
    # log.warn @model.model_path
  end

  # table[:column_count] = table[:columns].length
  # table[:display_column_count] = table[:column_count].to_s
  # table[:column_names] = column_names
  # table[:display_column_names] = column_names.join(',') unless table[:state].include?(:has_ruby_model)
end
