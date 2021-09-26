log.warn snake.parse('RailsDomainActions') if AppDebug.require?

require_relative './step'
require_relative './step1_attach_db_schema'
require_relative './step2_attach_models'
require_relative './step3_attach_columns'
require_relative './step4_attach_erd_files_models'
require_relative './step5_attach_data_dictionary'

# Takes a DB schema.json file, iterates the tables and reads the source code
# within rails model.rb files looking for DSL methods and other code that can
# help develop are rich schema.
class RailsDomainActions < BaseAction
  attr_reader :filter
  attr_reader :domain

  def initialize(context, opts)
    super(context, opts)

    # G.custom_actions.generate_guards(required: %i[transform show_read_model show_read_model_format build_domain_model source_file source_model_path target_file])
    guard('missing option source_model_path')           if opts.source_model_path.nil?
    guard('missing option source_file')                 if opts.source_file.nil?
    guard('missing option target_step_file')            if opts.target_step_file.nil?
    guard('missing option target_file')                 if opts.target_file.nil?

    guard('missing option transform')                   if opts.transform.nil?
    guard('missing option open')                        if opts.open.nil?
  end

  def execute
    return unless execute?

    transform                                           if opts.transform
  end

  private

  def transform
    # log.error('transform')

    # Consider moving domain_data into context

    Step1AttachDbSchema.run(context, opts, domain_data: domain_data, schema: schema)

    
    write(step: '-1-attach-db-schema')

    Step2AttachModels.run(context, opts, domain_data: domain_data)

    write(step: '-2-attach-models')

    # NOTE: Need to validate that foreign_table exists
    Step3AttachColumns.run(context, opts, domain_data: domain_data)

    write(step: '-3-attach-columns')

    Step4AttachRubyDslModels.run(context, opts, domain_data: domain_data)

    write(step: '-4-attach-rails-dsl-models')

    Step5AttachDataDictionary.run(context, opts, domain_data: domain_data)

    write(step: '-step5_attach_data_dictionary')

    write()

    builder.vscode(opts.target_file) if opts.open
  rescue => exception
    
  end

  def write(step: nil)
    file = target_step_file(step: step)
    File.write(file, JSON.pretty_generate(domain_data))
  end

  def target_step_file(step: nil)
    opts.target_step_file % { step: step }
  end

  def domain_data
    # The initial domain model structure is created here, but populated during the workflows.
    @domain_data ||= {
      domain: {
        models: [],
        erd_files: [],
        dictionary: [],
      },
      database: {
      },
      investigate: {
        investigations: [] # things to investigate
      }
    }
  end

  def schema
    raise 'Source DB schema not found' unless File.exist?(opts.source_file)

    content = File.read(opts.source_file)
    KUtil.data.json_parse(content, as: :hash_symbolized)
  end
end
