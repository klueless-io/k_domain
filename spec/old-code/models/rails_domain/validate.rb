class Validate
  KEYS = [:on]

  attr_accessor :methods

  attr_accessor :on

  def format_on
    for_template(self.on)
  end

  def for_template(value)
    return nil if value.nil?
    return value.to_s if value.is_a?(Hash)
    return ":#{value}" if value.is_a?(Symbol)
    value
  end
end
