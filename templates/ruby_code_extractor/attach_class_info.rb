module RubyCodeExtractor
  module AttachClassInfo
    def class_info
      @class_info ||= nil
    end

    def class_info=(value)
      @class_info = value
    end
  end
end
