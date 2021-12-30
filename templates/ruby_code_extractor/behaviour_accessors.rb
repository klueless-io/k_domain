module RubyCodeExtractor
  # When you intercept a method call, you can persist the captured paramaters
  # into a Hash, the Hash Key should be the method name and the value should
  # be a Hash with captured values.
  #
  # Use set/add for standard Rails DSL methods
  # Use custom_set/custom_add for non standard or 3rd party GEM methods
  module BehaviourAccessors
    def set(key, value)
      class_info[key] = class_info[key] || {}
      class_info[key] = value
    end

    def add(key, value)
      class_info[key] = class_info[key] || []
      if value.is_a?(Array)
        class_info[key] = class_info[key] + value
      else
        class_info[key] << value
      end
    end

    def custom_set(key, value = {})
      class_info[:custom] = {} unless class_info[:custom]
      class_info[:custom][key] = class_info[:custom][key] || {}
      class_info[:custom][key] = value
    end

    def custom_add(key, value)
      class_info[:custom] = {} unless class_info[:custom]
      class_info[:custom][key] = class_info[:custom][key] || []
      if value.is_a?(Array)
        class_info[:custom][key] = class_info[:custom][key] + value
      else
        class_info[:custom][key] << value
      end
    end
  end
end