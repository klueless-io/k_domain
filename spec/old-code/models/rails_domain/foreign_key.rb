class ForeignKey
  KEYS = [:column, :name, :on_update, :on_delete]

  attr_accessor :left
  attr_accessor :right

  attr_accessor :column
  attr_accessor :name
  attr_accessor :on_update
  attr_accessor :on_delete
end
