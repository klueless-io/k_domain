log.warn 'models' if AppDebug.require?

require 'dry-struct'

module Types
  include Dry.Types()
end

# This is useful if you want to initialize structures via Hash
class SymbolizeStruct < Dry::Struct
  transform_keys(&:to_sym)
end

require_relative './sql_count/_'
require_relative './rails_db_schema/_'
require_relative './rails_domain/_'

# require_relative './domain/_'
# require_relative './rails_code_references/_'
