# Store the raw schema for the tables that are used in the original PrintSpeak database
class SchemaPrintspeak
  def self.instance
    @instance ||= SchemaPrintspeak.new
  end

  attr_accessor :tables

  def initialize
    @tables = []
    @current_table = nil
    load_tables
  end
  private

  def add_table(table)
    @tables.push(table)
    @current_table = table
  end

  def add_index(_table_name, columns, **opts)
    @current_table[:indexes] = [] if @current_table[:indexes].nil?

    @current_table[:indexes].push({columns: columns}.merge(opts))
  end

  # ----------------------------------------------------------------------
  # Inject start
  # original file: {{source_file}}
  # ----------------------------------------------------------------------
  def load_tables
{{rails_schema}}
  end


  def write_json(file)
    schema[:meta][:rails] = @rails_version
    File.write(file, JSON.pretty_generate(schema))
  end

  # This is the rails timestamp and will be replaced by the action rails version
  def load(version:)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    # puts 'about to load'
    yield if block_given?

    schema[:meta][:rails] = @rails_version

    sort
    # code to time

    # log.kv 'extensions', schema[:db_info][:extensions].length
    # log.kv 'tables', schema[:tables].length
    # log.kv 'indexes', schema[:indexes].length  
    # # a low foreign_keys count is indicative of not using SQL referential integrity
    # log.kv 'foreign_keys', schema[:foreign_keys].length
    # log.kv 'Time Taken', (finish - start)

    # puts schema[:db_info][:extensions]
    # print_unique_keys(type: :foreign_keys, title: 'unique options for foreign_keys')
    # print_unique_keys(type: :columns, title: 'unique options for columns')
    # print_unique_keys(type: :fields, category: :integer , title: 'unique options for column - integer')
    # print_unique_keys(type: :fields, category: :decimal , title: 'unique options for column - decimal')
    # print_unique_keys(type: :fields, category: :string  , title: 'unique options for column - string')
    # print_unique_keys(type: :fields, category: :datetime, title: 'unique options for column - datetime')
    # print_unique_keys(type: :fields, category: :date    , title: 'unique options for column - date')
    # print_unique_keys(type: :fields, category: :text    , title: 'unique options for column - text')
    # print_unique_keys(type: :fields, category: :boolean , title: 'unique options for column - boolean')
    # print_unique_keys(type: :fields, category: :jsonb   , title: 'unique options for column - jsonb')
    # print_unique_keys(type: :fields, category: :hstore  , title: 'unique options for column - hstore')
    # print_unique_keys(type: :fields, category: :float   , title: 'unique options for column - float')
  end

  def enable_extension(name)
    # puts "enable_extension(#{name})"
    schema[:meta][:db_info][:extensions] << name
  end

  def create_table(name, **opts)
    id = opts[:id]
    primary_key = opts[:primary_key] || (id == false ? nil : "id")
    primary_key_type = if id == false
                         nil
                       elsif id.nil?
                         "bigint"
                       else
                         id
                       end

    @current_table = {
      name: name,
      primary_key: primary_key,                           # infer the actual value that should be in the database
      primary_key_type: primary_key_type,                 # infer the actual value that should be in the database
      columns: [],
      indexes: [],
      rails_schema: {                                     # as reported by the rails schema
        primary_key: opts[:primary_key],
        id: id,
        force: opts[:force]
      }
    }
    # schema[:tables][name] = @current_table
    schema[:tables] << @current_table
    
    yield(self) if block_given?
  end

  def add_field(name, type, **opts)
    # puts "add_field(#{name}, #{type})"
    row = { name: name, type: type, **opts }
    @current_table[:columns] << row

    add_unique_keys(row.keys, type: :columns)
    add_unique_keys(row.keys, type: :fields, category: type)
  end

  def add_index(name, fields, **opts)
    # puts "add_index(#{name})"
    row = { name: name, fields: fields, **opts }
    @current_table[:indexes] << row
    schema[:indexes] << row
    add_unique_keys(row.keys, type: :indexes)
  end

  # This method was introduced onto the schema in rails 5
  def index(fields, **opts)
    @rails_version = 5
    name = opts[:name]
    opts.delete(:name)
    add_index(name, fields, **opts)
  end

  def create_view(name, **opts)
    row = { name: name, **opts }
    schema[:views] << row
    add_unique_keys(row.keys, type: :views)
  end

  def add_foreign_key(left_table, right_table, **opts)
    # puts "add_foreign_key(#{left_table}, #{right_table})"
    row = { left: left_table, right: right_table, **opts }
    schema[:foreign_keys] << row
    add_unique_keys(row.keys, type: :foreign_keys)
  end

  def add_unique_keys(keys, type:, category: nil)
    key = [type, category, keys.join('-')].compact.join('|')
    return if @unique_keys.key?(key)

    @unique_keys[key] = key
    schema[:meta][:unique_keys] << { type: type, category: category, key: keys.join(','), keys: keys }
  end

  def print_unique_keys(type:, category: nil, title: )
    log.section_heading(title)

    filter_key_infos = schema[:meta][:unique_keys].select { |key_info| key_info[:type] == type && (category.nil? || key_info[:category] == category) }

    # log.kv 'all', filter_key_infos.flat_map { |key_info| key_info[:keys] }.uniq, 50

    filter_key_infos.each do |key_info|
      log.kv key_info[:key], key_info[:keys], 50
    end
  end

  def integer(name, **opts)
    add_field(name, :integer, **opts)
  end

  def bigint(name, **opts)
    add_field(name, :bigint, **opts)
  end

  def decimal(name, **opts)
    add_field(name, :decimal, **opts)
  end

  def string(name, **opts)
    add_field(name, :string, **opts)
  end

  def datetime(name, **opts)
    add_field(name, :datetime, **opts)
  end

  def date(name, **opts)
    add_field(name, :date, **opts)
  end

  def text(name, **opts)
    add_field(name, :text, **opts)
  end

  def boolean(name, **opts)
    add_field(name, :boolean, **opts)
  end

  def jsonb(name, **opts)
    add_field(name, :jsonb, **opts)
  end

  def hstore(name, **opts)
    add_field(name, :hstore, **opts)
  end

  def float(name, **opts)
    add_field(name, :float, **opts)
  end

  def sort
    schema[:indexes].sort_by! { |i| i[:name] }
    schema[:tables].each { |table| table[:indexes].sort_by! { |i| i[:name] } }

    # Insert a key that represents all unique keys, and then sort
    unique_keys_per_group = schema[:meta][:unique_keys]
      .group_by { |key_info| [key_info[:type], key_info[:category]] }
      .map do |group, values|
        all_keys = values.flat_map { |key_info| key_info[:keys] }.uniq
        { 
          type: group[0],
          category: group[01],
          key: 'all',
          keys: all_keys
        }
      end

    schema[:meta][:unique_keys].concat(unique_keys_per_group)
    schema[:meta][:unique_keys].sort! { |a,b| ([a[:type], a[:category],a[:key]] <=> [b[:type], b[:category],b[:key]]) }
  end

end
