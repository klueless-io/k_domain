# Rails model represents information that is found the model.rb class in the rails project
class EntityStatistics
  attr_accessor :column_counts
  attr_accessor :code_counts
  attr_accessor :code_dsl_counts
  attr_accessor :data_counts
  attr_accessor :issues

  def initialize(entity)
    # @column_counts = OpenStruct.new(meta[:column_counts])
    # @code_counts = OpenStruct.new(meta[:code_counts])
    # @code_dsl_counts = OpenStruct.new(meta[:code_dsl_counts])
    # @data_counts = OpenStruct.new(meta[:data_counts])
    # @issues = meta[:issues]
  end
end
