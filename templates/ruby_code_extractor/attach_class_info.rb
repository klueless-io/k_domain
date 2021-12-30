module RubyCodeExtractor
  # Class Info hash that contains the class name and any other key/values
  # that could be useful when capturing Class information.
  module AttachClassInfo
    def class_info
      @class_info ||= nil
    end

    def class_info=(value)
      @class_info = value
    end
  end
end
