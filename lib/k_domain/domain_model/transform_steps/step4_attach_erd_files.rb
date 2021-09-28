# frozen_string_literal: true

# Attach source code found in rails model definitions to models
class Step4AttachErdFiles < KDomain::DomainModel::Step
  attr_accessor :ruby_code

  # NOTE: This code could be rewritten using monkey patched modules and peak
  def call
    domain[:erd_files] = domain_models.map { |model| load_dsl(model) }
  end

  private

  def reset_dsl
    @ruby_code = nil
    @dsl = nil
  end

  def dsl
    @dsl ||= {
      name: '',
      name_plural: ''
    }
  end

  def load_dsl(model)
    reset_dsl

    dsl[:name]        = model[:name]
    dsl[:name_plural] = model[:name_plural]
    dsl[:dsl_file]    = model[:erd_location][:exist] ? model[:erd_location][:file] : ''

    return dsl unless File.exist?(dsl[:dsl_file])

    @ruby_code = File.read(dsl[:dsl_file])

    dsl[:source]  = read_dsl_source
    dsl[:dsl]     = build_dsl
    dsl[:todo]    = todo

    dsl
  end

  def read_dsl_source
    regex_split_private_public = /(?<public>.+?)(?=\bprivate\b)(?<private>.*)/m

    split_code = regex_split_private_public.match(ruby_code)

    public_code = nil
    private_code = nil

    if split_code
      public_code = split_code[:public]
      private_code = split_code[:private]
    end

    {
      ruby: ruby_code,
      public: public_code,
      private: private_code,
      all_methods: grab_methods(public_code, private_code)
    }
  end

  def build_dsl
    return if ruby_code.nil?

    # need to support options as hash instead of options as string in the future
    {
      default_scope: grab_default_scope,
      scopes: grab_scopes,
      belongs_to: grab_belongs_to,
      has_one: grab_has_one,
      has_many: grab_has_many,
      has_and_belongs_to_many: grab_has_and_belongs_to_many,
      validate_on: grab_validate,
      validates_on: grab_validates
    }

    # ^(?<spaces>\s*)(?<event_type>before_create|before_save|before_destroy|after_create|after_save|after_destroy) (:(?<name>\w*)[, ]?(?<scope>.*)|(?<scope>\{.*?\}.*$))
  end

  def grab_default_scope
    regex = /default_scope \{(?<scope>.*?)\}/m

    m = regex.match(ruby_code)

    return "{ #{m[:scope].strip.gsub('\n', '')} }" if m

    nil
  end

  def grab_scopes
    entries = []
    # Start from beginning of line and capture
    # - number of spaces scope
    # - name of scope
    # - value of scope to end of line
    regex = /^(?<spaces>\s*)scope :(?<name>\w*)[, ]?(?<scope>.*)/

    # rubocop:disable Metrics/BlockLength
    ruby_code.scan(regex) do
      m = $LAST_MATCH_INFO
      spaces = m[:spaces] # .delete("\n")
      last_lf = spaces.rindex("\n")
      spaces = last_lf ? spaces[spaces.rindex("\n") + 1..-1] : spaces
      name = m[:name]
      scope = m[:scope].strip

      # Found a valid one liner
      if scope.ends_with?('}') && (scope.scan(/{/).count == scope.scan(/}/).count)
        scope = escape_single_quote(scope)
        entries << { name: name, scope: scope }
      else
        # Have a multiline scope, lets see if it is cleanly formatted

        start_anchor = "#{spaces}scope :#{name}"
        end_anchor = "#{spaces}}"

        # log.kv 'spaces', spaces.length
        # log.kv 'name', name
        # log.kv 'start_anchor', start_anchor
        # log.kv 'end_anchor', end_anchor

        start_index = ruby_code.index(/#{start_anchor}/)

        if start_index.nil?
          log.error("[#{@current_entity[:name]}] could not find [start] anchor index for [#{name}]")
        else
          ruby_section = ruby_code[start_index..-1]
          end_index = ruby_section.index(/^#{end_anchor}/) # Add ^ start of line
          if end_index.nil?
            log.error("[#{@current_entity[:name]}] could not find [end] anchor index for [#{name}]")
          else
            scope = ruby_section[start_anchor.length + 1..end_index].strip
            scope = escape_single_quote("#{scope}#{end_anchor}")
            entries << { name: name, scope: scope }
          end
        end
      end
    end
    entries
  rescue StandardError => e
    # bin ding.pry
    puts e.message
  end
  # rubocop:enable Metrics/BlockLength

  def grab_belongs_to
    entries = []

    # Start from beginning of line and capture
    # - number of spaces before belongs_to
    # - name of the belongs_to
    # - value of belongs_to to end of line
    regex = /^(?<spaces>\s*)belongs_to :(?<name>\w*)[, ]?(?<options>.*)/

    ruby_code.scan(regex) do
      m = $LAST_MATCH_INFO

      # spaces = m[:spaces] # .delete("\n")
      # last_lf = spaces.rindex("\n")
      # spaces = last_lf ? spaces[spaces.rindex("\n") + 1..-1] : spaces
      name = m[:name]

      options = m[:options]
                .gsub(':polymorphic => ', 'polymorphic: ')
                .gsub(':class_name => ', 'class_name: ')
                .gsub(':foreign_key => ', 'foreign_key: ')
                .strip

      options = clean_lambda(options)

      entries << { name: name, options: extract_options(options), raw_options: options }
    end
    entries
  rescue StandardError => e
    # bin ding.pry
    puts e.message
  end

  def grab_has_one
    entries = []

    # Start from beginning of line and capture
    # - number of spaces before has_one
    # - name of the has_one
    # - value of has_one to end of line
    regex = /^(?<spaces>\s*)has_one :(?<name>\w*)[, ]?(?<options>.*)/

    ruby_code.scan(regex) do
      m = $LAST_MATCH_INFO

      # spaces = m[:spaces] # .delete("\n")
      # last_lf = spaces.rindex("\n")
      # spaces = last_lf ? spaces[spaces.rindex("\n") + 1..-1] : spaces
      name = m[:name]
      options = m[:options]
                .strip
      # .gsub(':polymorphic => ', 'polymorphic: ')
      # .gsub(':class_name => ', 'class_name: ')
      # .gsub(':foreign_key => ', 'foreign_key: ')

      options = clean_lambda(options)

      entries << { name: name, options: extract_options(options), raw_options: options }
    end
    entries
  rescue StandardError => e
    # bin ding.pry
    puts e.message
  end

  def grab_has_many
    entries = []
    # Start from beginning of line and capture
    # - number of spaces before has_many
    # - name of the has_many
    # - value of has_many to end of line
    regex = /^(?<spaces>\s*)has_many :(?<name>\w*)[, ]?(?<options>.*)/

    ruby_code.scan(regex) do
      m = $LAST_MATCH_INFO

      # spaces = m[:spaces] # .delete("\n")
      # last_lf = spaces.rindex("\n")
      # spaces = last_lf ? spaces[spaces.rindex("\n") + 1..-1] : spaces
      name = m[:name]
      options = m[:options]
                .gsub(':dependent => ', 'dependent: ')
                .gsub(':class_name => ', 'class_name: ')
                .gsub(':foreign_key => ', 'foreign_key: ')
                .gsub(':primary_key => ', 'primary_key: ')
                .strip

      options = clean_lambda(options)

      entries << { name: name, options: extract_options(options), raw_options: options }
    end
    entries
  rescue StandardError => e
    # bin ding.pry
    puts e.message
  end

  def grab_has_and_belongs_to_many
    entries = []
    # Start from beginning of line and capture
    # - number of spaces before has_and_belongs_to_many
    # - name of the has_and_belongs_to_many
    # - value of has_and_belongs_to_many to end of line
    regex = /^(?<spaces>\s*)has_and_belongs_to_many :(?<name>\w*)[, ]?(?<options>.*)/

    ruby_code.scan(regex) do
      m = $LAST_MATCH_INFO

      # spaces = m[:spaces] # .delete("\n")
      # last_lf = spaces.rindex("\n")
      # spaces = last_lf ? spaces[spaces.rindex("\n") + 1..-1] : spaces
      name = m[:name]
      options = m[:options]
                .gsub(':dependent => ', 'dependent: ')
                .gsub(':class_name => ', 'class_name: ')
                .gsub(':foreign_key => ', 'foreign_key: ')
                .gsub(':primary_key => ', 'primary_key: ')
                .strip

      options = clean_lambda(options)

      entries << { name: name, options: {}, raw_options: options }
    end
    entries
  rescue StandardError => e
    # bin ding.pry
    puts e.message
  end

  def grab_validates
    entries = []
    # Start from beginning of line and capture
    # - number of spaces before validates
    # - name of the validates
    # - value of validates to end of line
    regex = /^(?<spaces>\s*)validates :(?<name>\w*)[, ]?(?<options>.*)/

    ruby_code.scan(regex) do
      m = $LAST_MATCH_INFO

      # spaces = m[:spaces] # .delete("\n")
      # last_lf = spaces.rindex("\n")
      # spaces = last_lf ? spaces[spaces.rindex("\n") + 1..-1] : spaces
      name = m[:name]

      options = m[:options].strip

      options = clean_lambda(options)

      entries << { name: name, raw_options: options }
    end
    entries
  rescue StandardError => e
    # bin ding.pry
    puts e.message
  end

  def grab_validate
    entries = []
    # Start from beginning of line and capture
    # - number of spaces before validate
    # - list of methods to call until to end of line
    # regex = /^(?<spaces>\s*)validate :(?<name>\w*)[, ]?(?<options>.*)/
    regex = /^(?<spaces>\s*)validate (?<line>:.*)/
    # puts @current_entity[:name]

    ruby_code.scan(regex) do
      m = $LAST_MATCH_INFO

      # spaces = m[:spaces] # .delete("\n")
      # last_lf = spaces.rindex("\n")
      # spaces = last_lf ? spaces[spaces.rindex("\n") + 1..-1] : spaces
      line = m[:line]

      entries << { line: line }
      # puts @current_entity[:validate]
    end
    entries
  rescue StandardError => e
    # bin ding.pry
    puts e.message
  end

  def grab_methods(public_code = ruby_code, private_code = nil)
    # public_code = ruby_code_public.nil? ? ruby_code : ruby_code_public
    # private_code = ruby_code_private

    regex = /def (?<method>.*)/

    # log.info(@current_entity[:name])

    public_methods    = parse_methods(:public, public_code&.scan(regex)&.flatten || [])
    private_methods   = parse_methods(:private, private_code&.scan(regex)&.flatten || [])
    methods           = (public_methods + private_methods)

    class_methods     = methods.select { |method| method[:class_method] == true }

    all_instance      = methods.select { |method| method[:class_method] == false }
    instance_public   = all_instance.select { |method| method[:scope] == :public }
    instance_private  = all_instance.select { |method| method[:scope] == :private }

    {
      klass: class_methods,
      instance: all_instance,
      instance_public: instance_public,
      instance_private: instance_private
    }
  end

  def parse_methods(scope, methods)
    methods.map do |value|
      class_method = value.starts_with?('self.')
      name = class_method ? value[5..-1] : value
      arguments = nil
      arguments_index = name.index('(')

      if arguments_index
        arguments = name[arguments_index..-1]
        name = name[0..arguments_index - 1]
      end

      arguments = escape_single_quote(arguments)

      {
        name: name,
        scope: scope,
        class_method: class_method,
        arguments: arguments&.strip.to_s
      }
    end
  end

  def todo
    {
      after_destroy: [], # to do
      before_save: [], # to do
      after_save: [], # to do
      before_create: [], # to do
      after_create: [], # to do
      enum: [], # to do
      attr_encrypted: [], # to do
      validates_uniqueness_of: [], # to do
      validates_confirmation_of: [], # to do
      attr_accessor: [], # to do
      attr_reader: [], # to do
      attr_writer: [] # to do
    }
  end

  def escape_single_quote(value)
    return nil if value.nil?

    value.gsub("'", "\\\\'")
  end

  # rubocop:disable Style/EvalWithLocation, Security/Eval, Style/DocumentDynamicEvalDefinition
  def extract_options(options)
    eval("{ #{options} }")
  rescue StandardError => e
    investigate(
      step: :step4_attach_erd_files_models,
      location: :extract_options,
      key: nil,
      message: e.message
    )
    {}
  rescue SyntaxError => e
    # may be the issue is from a comment at the off the line
    comment_index = options.rindex('#') - 1

    if comment_index.positive?
      options_minus_comment = options[0..comment_index].squish
      return extract_options(options_minus_comment)
    end

    investigate(
      step: :step4_attach_erd_files_models,
      location: :extract_options,
      key: nil,
      message: e.message
    )
    {}
  end
  # rubocop:enable Style/EvalWithLocation, Security/Eval, Style/DocumentDynamicEvalDefinition

  def clean_lambda(options)
    if /^->/.match?(options)
      index = options.index(/}\s*,/)
      if index.nil?
        if options.count('{') == options.count('}')
          index = options.rindex(/}/)
          options = "a_lambda: '#{escape_single_quote(options[0..index])}'"
        else
          log.error(options)
          options = "a_lambda: '#{escape_single_quote(options)}'"
        end
      else
        options = "a_lambda: '#{escape_single_quote(options[0..index])}', #{options[index + 2..-1]}"
      end
    end
    options
  rescue StandardError => e
    # bin ding.pry
    puts e.message
  end
end
