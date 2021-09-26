# Rails model represents information that is found the model.rb class in the rails project
class RailsModel

  attr_accessor :name
  attr_accessor :name_plural
  attr_accessor :name_original
  attr_accessor :documentation_rel_path
  attr_accessor :model_path

  # @param [Symbol] value The value of ID has different meanings
  # @option value :true Id column exists and it uses an Integer type
  # @option value :false Id column does not exist
  # @option value :bigserial Id column exists and it uses a BigSerial type
  attr_accessor :id

  attr_accessor :force
  attr_accessor :primary_key
  attr_accessor :quirks

  attr_accessor :ruby_raw
  attr_accessor :ruby_code
  attr_accessor :ruby_frozen
  attr_accessor :ruby_header
  attr_accessor :ruby_code_public
  attr_accessor :ruby_code_private
  
  attr_accessor :default_scope
  attr_accessor :scopes
  attr_accessor :public_class_methods
  attr_accessor :public_instance_methods
  attr_accessor :private_instance_methods

  # stats
  attr_accessor :time_stamp1
  attr_accessor :time_stamp2
  attr_accessor :time_stamp3

  def code_length
    ruby_raw&.length
  end

  def display_quirks
    quirks.join(' ')
  end

  def exists?
    File.exist?(model_path)
  end

  def initialize
    @quirks = []
  end

  def add_quirk(quirk)
    @quirks << quirk
  end

  def to_h
    {
      name: name,
      name_plural: name_plural,
      name_original: name_original,
      documentation_rel_path: documentation_rel_path,
      model_path: model_path,
      id: id,
      force: force,
      primary_key: primary_key,
      quirks: quirks,
      ruby_raw: ruby_raw,
      ruby_code: ruby_code,
      ruby_frozen: ruby_frozen,
      ruby_header: ruby_header,
      ruby_code_public: ruby_code_public,
      ruby_code_private: ruby_code_private,
      default_scope: default_scope,
      scopes: scopes,
      public_class_methods: public_class_methods,
      public_instance_methods: public_instance_methods,
      private_instance_methods: private_instance_methods,
      time_stamp1: time_stamp1,
      time_stamp2: time_stamp2,
      time_stamp3: time_stamp3,
      code_length: code_length,
      exists: exists?
    }
  end
end
