log.warn snake.parse('DataContext-LoadSqlCount') if AppDebug.require?

# Read SQL count data from database -> csv file
class LoadRailsDbSchema < BaseStep
  attr_reader :data

  def run
    rails "Rails DB Schema file not found #{opts.rails_db_schema_file}" unless File.exist?(opts.rails_db_schema_file)

    json = File.read(opts.rails_db_schema_file)
    data = KUtil.data.json_parse(json, as: :hash_symbolized)
    
    @data = RailsDbSchema::Schema.new(data)
    # as_struct = KUtil.data.to_open_struct(@data)
  end
end