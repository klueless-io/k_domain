class Validates
  KEYS = [:length, :unless, :format, :presence]

  attr_accessor :name

  attr_accessor :length
  attr_accessor :unless
  attr_accessor :format
  attr_accessor :presence

  def format_length
    for_template(self.length)
  end
  def format_unless
    for_template(self.unless)
  end
  def format_format
    for_template(self.format)
  end
  def format_presence
    for_template(self.presence)
  end

  def for_template(value)
    return nil if value.nil?
    return value.to_s if value.is_a?(Hash)
    return ":#{value}" if value.is_a?(Symbol)
    value
  end

  def to_h
    {
      name: name,
      length: length,
      unless: self.unless,
      format: self.format,
      presence: presence
    }
  end
end
