class HasOne
  # KEYS = [:model_name, :model_name_plural, :a_lambda, :class_name, :foreign_key, :primary_key, :infer_key]
  KEYS = [:a_lambda, :class_name, :foreign_key, :primary_key, :infer_key, :code_duplicate]

  attr_accessor :name
  
  attr_accessor :model_name
  attr_accessor :model_name_plural

  attr_accessor :a_lambda
  attr_accessor :class_name
  attr_accessor :foreign_key
  attr_accessor :primary_key

  def infer_key
    primary_key.nil? ? "#{name}_id" : primary_key
  end

  attr_accessor :related_entity
  attr_accessor :code_duplicate

  def to_h
    {
      name: name,
      model_name: model_name,
      model_name_plural: model_name_plural,
      a_lambda: a_lambda,
      class_name: class_name,
      foreign_key: foreign_key,
      primary_key: primary_key,
      code_duplicate: code_duplicate,
      related_entity: related_entity.to_h
    }
  end
end
