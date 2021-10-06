# frozen_string_literal: true

# The require order is important due to dependencies
require_relative './step'
require_relative './step1_attach_db_schema'
require_relative './step2_attach_models'
require_relative './step3_attach_columns'
require_relative './step4_rails_resource_models'
require_relative './step5_rails_structure_models'
require_relative './step6_attach_dictionary'
