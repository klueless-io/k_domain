# frozen_string_literal: true

module Types
  include Dry.Types()
end

# The require order is important due to dependencies
require_relative './column'
require_relative './database'
require_relative './index'
require_relative './table'
require_relative './foreign_key'
require_relative './unique_key'
require_relative './schema'
