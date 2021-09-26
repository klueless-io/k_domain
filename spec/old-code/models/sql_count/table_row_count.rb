# frozen_string_literal: true

# How many rows are in the database for each table in each region
module SqlCount
  class TableRowCount < SymbolizeStruct
    transform_keys(&:to_sym)

    attribute :table_name   , Types::Strict::String
    attribute :au           , Types::Strict::Integer
    attribute :eu           , Types::Strict::Integer
    attribute :us           , Types::Strict::Integer
  end
end