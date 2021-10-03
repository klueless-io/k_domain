module ActiveRecord
  def self.current_class
    @current_class ||= nil
  end

  def self.current_class=(value)
    @current_class = value
  end

  class Base
    def self.singleton_class
      Class.new do
        def send(*_p, **_o); end
      end.new
    end

    def self.class_info
      return ActiveRecord.current_class if ActiveRecord.current_class

      ActiveRecord.current_class = {
        class_name: name
      }
    end

    def self.set(key, value)
      class_info[key] = class_info[key] || {}
      class_info[key] = value
    end

    def self.add(key, value)
      class_info[key] = class_info[key] || []
      if value.is_a?(Array)
        class_info[key] = class_info[key] + value
      else
        class_info[key] << value
      end
    end

    def self.custom_set(key, value = {})
      class_info[:custom] = {} unless class_info[:custom]
      class_info[:custom][key] = class_info[:custom][key] || {}
      class_info[:custom][key] = value
    end

    def self.custom_add(key, value)
      class_info[:custom] = {} unless class_info[:custom]
      class_info[:custom][key] = class_info[:custom][key] || []
      if value.is_a?(Array)
        class_info[:custom][key] = class_info[:custom][key] + value
      else
        class_info[:custom][key] << value
      end
    end

    # examples:
    # enum status: { active: 0, archived: 1 }
    # enum status: [:active, :archived]
    # enum status: [:active, :archived], _suffix: true
    # enum comments_status: [:active, :inactive], _prefix: :comments
    def self.enum(**opts)
      add(:enum, opts)
    end

    def self.attr_accessor(*names)
      add(:attr_accessor, names)
    end

    def self.attr_reader(*names)
      add(:attr_reader, names)
    end

    def self.attr_writer(*names)
      add(:attr_writer, names)
    end

    def self.lambda_source(a_lambda, prefix = nil)
      return nil unless a_lambda

      puts 'NOT A LAMBDA' unless a_lambda.is_a?(Proc)

      result = a_lambda&.source&.strip
      result = result&.delete_prefix(prefix) if prefix
      result&.strip
    end

    # examples
    # default_scope where(:published => true) # NOT supported
    # default_scope { where(:published_at => Time.now - 1.week) }
    # default_scope -> { order(:external_updated_at) }
    # default_scope -> { where(:published => true) }, all_queries: true
    def self.default_scope(**opts, &block)
      block_source = nil
      block_source = lambda_source(block, 'default_scope') if block_given?

      set(:default_scope, opts.merge(block: block_source))
    end

    # examples
    # scope :red, where(:color => 'red') # NOT SUPPORTED
    # scope :dry_clean_only, joins(:washing_instructions).where('washing_instructions.dry_clean_only = ?', true) # NOT SUPPORTED
    #
    def self.scope(name, on_the_lamb = nil, **opts)
      lamb_source = lambda_source(on_the_lamb, "scope :#{name},")

      add(:scopes, {
            name: name,
            opts: opts,
            block: lamb_source
          })
    end

    def self.belongs_to(name, on_the_lamb = nil, **opts)
      lamb_source = lambda_source(on_the_lamb, "belongs_to :#{name},")

      add(:belongs_to, {
            name: name,
            opts: opts,
            block: lamb_source
          })
    end

    def self.has_many(name, on_the_lamb = nil, **opts)
      lamb_source = lambda_source(on_the_lamb, "has_many :#{name},")

      add(:has_many, {
            name: name,
            opts: opts,
            block: lamb_source
          })
    end

    def self.has_one(name, on_the_lamb = nil, **opts)
      lamb_source = lambda_source(on_the_lamb, "has_one :#{name},")

      add(:has_one, {
            name: name,
            opts: opts,
            block: lamb_source
          })
    end

    def self.has_and_belongs_to_many(name, on_the_lamb = nil, **opts)
      lamb_source = lambda_source(on_the_lamb, "has_and_belongs_to_many :#{name},")

      add(:has_and_belongs_to_many, {
            name: name,
            opts: opts,
            block: lamb_source
          })
    end

    def self.validate(*names, **opts, &block)
      block_source = nil
      block_source = lambda_source(block, 'validate') if block_given?

      add(:validate, {
            names: names,
            opts: opts,
            block: block_source
          })
    end

    def self.validates(name, **opts)
      add(:validates, {
            name: name,
            opts: opts
          })
    end

    def self.alias_attribute(left, right)
      add(:alias_attribute, {
            left: left,
            right: right
          })
    end

    def self.before_create(name)
      add(:before_create, {
            name: name
          })
    end

    def self.before_save(name)
      add(:before_save, {
            name: name
          })
    end

    def self.before_destroy(name)
      add(:before_destroy, {
            name: name
          })
    end

    def self.before_validation(name = nil, &block)
      block_source = nil
      block_source = lambda_source(block, 'before_validation') if block_given?

      add(:before_validation, {
            name: name,
            block: block_source
          })
    end

    def self.after_create(name)
      add(:after_create, {
            name: name
          })
    end

    def self.after_save(name)
      add(:after_save, {
            name: name
          })
    end

    def self.after_destroy(name = nil, &block)
      block_source = nil
      block_source = lambda_source(block, 'after_destroy') if block_given?

      add(:after_destroy, {
            name: name,
            block: block_source
          })
    end

    def self.after_commit(name)
      add(:after_commit, {
            name: name
          })
    end

    def self.accepts_nested_attributes_for(name, **opts)
      add(:accepts_nested_attributes_for, {
            name: name,
            opts: opts
          })
    end

    def self.has_secure_token(name)
      add(:has_secure_token, {
            name: name
          })
    end

    # CAN THESE BE AUTOMATED LIKE INCLUDE MODULES
    def self.establish_connection(connection)
      class_info[:establish_connection] = connection
    end

    def self.store_accessor(*names)
      class_info[:store_accessor] = *names
    end

    def self.table_name=(table_name)
      class_info[:table_name] = table_name
    end

    def self.primary_key=(primary_key)
      class_info[:primary_key] = primary_key
    end

    def self.require(require)
      add(:require, require)
    end

    def self.devise(*names)
      add(:devise, names)
    end

    def self.pg_search_scope(name, **opts)
      custom_set(:pg_search_scope, {
                   name: name,
                   opts: opts
                 })
    end

    def self.acts_as_readable(**opts)
      custom_set(:acts_as_readable, {
                   opts: opts
                 })
    end

    def self.acts_as_reader
      custom_set(:acts_as_reader, {})
    end

    def self.acts_as_commentable
      custom_set(:acts_as_commentable, {})
    end

    def self.acts_as_list(**opts)
      custom_set(:acts_as_list, {
                   opts: opts
                 })
    end

    def self.has_paper_trail
      custom_set(:has_paper_trail)
    end

    def self.validates_uniqueness_of(name, **opts)
      custom_set(:validates_uniqueness_of, {
                   name: name,
                   opts: opts
                 })
    end

    def self.validates_presence_of(name, **opts)
      custom_set(:validates_presence_of, {
                   name: name,
                   opts: opts
                 })
    end

    def self.validates_length_of(name, **opts)
      custom_set(:validates_length_of, {
                   name: name,
                   opts: opts
                 })
    end

    def self.attr_encrypted(name, **opts)
      custom_set(:attr_encrypted, {
                   name: name,
                   opts: opts
                 })
    end

    def self.validates_confirmation_of(name, **opts)
      custom_set(:validates_confirmation_of, {
                   name: name,
                   opts: opts
                 })
    end

    def self.with_options(opts, &block)
      block_source = nil
      block_source = lambda_source(block) if block_given?

      custom_add(:with_options, {
                   opts: opts,
                   block: block_source
                 })
    end
  end
end
