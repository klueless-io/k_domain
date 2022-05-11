# frozen_string_literal: true

RSpec.describe 'KDomain::DomainModelSchema::SamplePrinter', :skip_on_gha do
  include KLog::Logging

  include_examples :domain_simple_settings
  # include_examples :domain_advanced_settings
  include_examples :load_domain_model

  let(:root_graph) do
    {
      investigate: { skip: true },
      domain: { skip: true },
      rails: { skip: true },
      rails_resource: { skip: true },
      rails_structure: { skip: true },
      database: { skip: true },
      dictionary: { skip: true }
    }
  end

  # let(:load_domain_model_file) { 'spec/sample_output/printspeak/main_dataset.json' }

  def show_length(array)
    return '' if array.nil?

    length = array.length
    length.zero? ? '' : length
  end

  def show_bool(value)
    return '' unless value

    value
  end

  def show_exist(value)
    return '' if value.nil?

    true
  end

  context 'print tables' do
    let(:graph) do
      {
        domain: {
          models: {
            title: 'Models',
            take: 5,
            columns: [
              :name,
              :name_plural,
              :table_name,
              :type,
              { pk:               { display_method: ->(row) { row.pk.name                            } } },
              { pk_type:          { display_method: ->(row) { row.pk.type                            } } },
              { pk_exist:         { display_method: ->(row) { row.pk.exist                           } } },
              # TODO: :main_key,
              # TODO: { traits:           { display_method: -> (row) { row.traits.join(',')                   } } },
              { column_count:     { display_method: ->(row) { show_length(row.columns)               } } },
              { for_data:         { display_method: ->(row) { show_length(row.columns_data)          } } },
              { for_primary:      { display_method: ->(row) { show_length(row.columns_primary)       } } },
              { for_fk:           { display_method: ->(row) { show_length(row.columns_foreign_key)   } } },
              { for_poly_fy:      { display_method: ->(row) { show_length(row.columns_foreign_type)  } } },
              { for_timestamp:    { display_method: ->(row) { show_length(row.columns_timestamp)     } } },
              { for_deleted_at:   { display_method: ->(row) { show_length(row.columns_deleted_at)    } } },
              { for_virtual:      { display_method: ->(row) { show_length(row.columns_virtual)       } } },
              { for_data_foreign: { display_method: ->(row) { show_length(row.columns_data_foreign)  } } }
            ]
          }
        }
      }
    end

    it do
      log.structure(load_domain_model, title: 'Models', line_width: 200, show_array_count: true, graph: root_graph.merge(graph))
    end
  end

  # TODO: THIS IS BROKEN
  # context 'print erd_files' do
  #   let(:graph) do
  #     {
  #       erd_files: {
  #         title: 'ERD Files',
  #         take: 5,
  #         columns: [
  #           :name,
  #           :name_plural,
  #           { dsl_file:                 { display_method: ->(row) { File.basename(row.dsl_file) } } },
  #           { ruby:                     { display_method: ->(row) { row.source&.ruby ? 'true' : '' } } },
  #           { has_public:               { display_method: ->(row) { row.source&.public ? 'true' : '' } } },
  #           { has_private:              { display_method: ->(row) { row.source&.private ? 'true' : '' } } },
  #           { class_methods:            { display_method: ->(row) { show_length(row.source&.all_methods&.klass) } } },
  #           { instance_methods:         { display_method: ->(row) { show_length(row.source&.all_methods&.instance) } } },
  #           { instance_public:          { display_method: ->(row) { show_length(row.source&.all_methods&.instance_public) } } },
  #           { instance_private:         { display_method: ->(row) { show_length(row.source&.all_methods&.instance_private) } } },
  #           { scopes:                   { display_method: ->(row) { show_length(row.dsl&.scopes) } } },
  #           { belongs_to:               { display_method: ->(row) { show_length(row.dsl&.belongs_to) } } },
  #           { has_one:                  { display_method: ->(row) { show_length(row.dsl&.has_one) } } },
  #           { has_many:                 { display_method: ->(row) { show_length(row.dsl&.has_many) } } },
  #           { has_and_belongs_to_many:  { display_method: ->(row) { show_length(row.dsl&.has_and_belongs_to_many) } } },
  #           { validate_on:              { display_method: ->(row) { show_length(row.dsl&.validate_on) } } },
  #           { validates_on:             { display_method: ->(row) { show_length(row.dsl&.validates_on) } } }
  #         ]
  #       },
  #     }
  #   end

  #   it do
  #     log.structure(load_domain_model, title: 'ERD Files', line_width: 200, show_array_count: true, graph: root_graph.merge(graph))
  #   end
  # end

  # TODO: DONE as model_list using rails_resource_models
  context 'print rails_resource' do
    context 'models' do
      let(:graph) do
        {
          rails_resource: {
            models: {
              # pry_at: [:before_array],
              take: 5,
              columns: [
                :model_name,
                :table_name,
                { file: { width: 200 } },
                :exist,
                { state: { width: 40 } }
              ]
            },
            routes: { skip: true },
            controllers: { skip: true }
          }
        }
      end

      it do
        log.structure(load_domain_model,
                      title: 'Rails Resources - Models',
                      line_width: 200, show_array_count: true,
                      graph: root_graph.merge(graph))
      end
    end
    context 'routes' do
      let(:graph) do
        {
          rails_resource: {
            models: { skip: true },
            routes: {
              # pry_at: [:before_array],
              take: 5,
              columns: [
                :uri_path,
                :mime_match,
                :name,
                :controller_name,
                :action,
                :controller_path,
                :controller_namespace,
                :controller_file,
                :controller_exist,
                { verbs: { width: 40, display_method: ->(row) { row.verbs.join(', ') } } },
                :duplicate_verb,
                { file: { width: 250, display_method: ->(row) { row.file[row.file.index('controllers') + 'controllers'.length..] } } }
              ]
            },
            controllers: { skip: true }
          }
        }
      end

      it do
        log.structure(load_domain_model,
                      title: 'Rails Resources - Routes',
                      line_width: 200, show_array_count: true,
                      graph: root_graph.merge(graph))

        # puts Dir.pwd
      end
    end
  end

  context 'print rails structures' do
    context 'models' do
      let(:graph) do
        {
          rails_structure: {
            models: {
              # pry_at: [:before_array],
              take: 5,
              title: 'Resource path - Rails Models',
              columns: [
                :model_name,
                :table_name,
                { file: { width: 50, display_method: ->(row) { row.file[-40..] || row.file } } },
                :exist,
                { state: { width: 40 } },
                { code: { display_method: ->(row) { !row.code.empty? } } },
                { class_name: { display_method: ->(row) { row.behaviours.class_name } } }
              ]
            },
            controllers: { skip: true }
          }
        }
      end

      it do
        log.structure(load_domain_model,
                      title: 'Rails Resources - Models',
                      line_width: 200, show_array_count: true,
                      graph: root_graph.merge(graph))
      end
    end

    context 'models (behaviours)' do
      let(:graph) do
        {
          rails_structure: {
            models: {
              # pry_at: [:before_array],
              filter: ->(row) { row.exist },
              take: :all,
              columns: [
                :model_name,
                :table_name,
                { class_name:               { display_method: ->(row) { row.behaviours.class_name                           } } },
                { default_scope:            { display_method: ->(row) { show_exist(row.behaviours.default_scope)            } } },
                { scopes:                   { display_method: ->(row) { show_length(row.behaviours.scopes)                  } } },
                { belongs_to:               { display_method: ->(row) { show_length(row.behaviours.belongs_to)              } } },
                { has_one:                  { display_method: ->(row) { show_length(row.behaviours.has_one)                 } } },
                { has_many:                 { display_method: ->(row) { show_length(row.behaviours.has_many)                } } },
                { has_and_belongs_to_many:  { display_method: ->(row) { show_length(row.behaviours.has_and_belongs_to_many) } } },
                { validate:                 { display_method: ->(row) { show_length(row.behaviours.validate)                } } },
                { validates:                { display_method: ->(row) { show_length(row.behaviours.validates)               } } },
                { attr_accessor:            { display_method: ->(row) { show_length(row.behaviours.attr_accessor)           } } },
                { attr_reader:              { display_method: ->(row) { show_length(row.behaviours.attr_reader)             } } },
                { attr_writer:              { display_method: ->(row) { show_length(row.behaviours.attr_writer)             } } }
              ]
            },
            controllers: { skip: true }
          }
        }
      end

      it do
        log.structure(load_domain_model,
                      title: 'Rails Resources - Model (Behaviours)',
                      line_width: 200, show_array_count: true,
                      graph: root_graph.merge(graph))
      end
    end

    context 'models (function)' do
      let(:graph) do
        {
          rails_structure: {
            models: {
              # pry_at: [:before_array],
              filter: ->(row) { row.exist },
              take: 5,
              columns: [
                :model_name,
                :table_name,
                { class_name:       { display_method: ->(row) { row.functions.class_name                      } } },
                { module_name:      { display_method: ->(row) { row.functions.module_name                     } } },
                { class_full_name:  { display_method: ->(row) { row.functions.class_full_name                 } } },
                { attr_accessor:    { display_method: ->(row) { show_length(row.functions.attr_accessor)      } } },
                { attr_reader:      { display_method: ->(row) { show_length(row.functions.attr_reader)        } } },
                { attr_writer:      { display_method: ->(row) { show_length(row.functions.attr_writer)        } } },
                { klass:            { display_method: ->(row) { show_length(row.functions.klass)              } } },
                { instance_public:  { display_method: ->(row) { show_length(row.functions.instance_public)    } } },
                { instance_private: { display_method: ->(row) { show_length(row.functions.instance_private)   } } }
              ]
            },
            controllers: { skip: true }
          }
        }
      end

      it do
        log.structure(load_domain_model,
                      title: 'Rails Resources - Model (Functions)',
                      line_width: 200, show_array_count: true,
                      graph: root_graph.merge(graph))
      end
    end

    context 'controllers' do
      let(:graph) do
        {
          rails_structure: {
            controllers: {
              # pry_at: [:before_array],
              take: 5,
              title: 'Resource path - Rails Controllers',
              columns: %i[
                name
                path
                namespace
                file
                exist
              ]
            },
            models: { skip: true }
          }
        }
      end

      it do
        log.structure(load_domain_model,
                      title: 'Rails Resources - Controllers',
                      line_width: 200, show_array_count: true,
                      graph: root_graph.merge(graph))
      end
    end

    context 'controllers (behaviours)' do
      let(:graph) do
        {
          rails_structure: {
            controllers: {
              # pry_at: [:before_array],
              filter: ->(row) { row.exist },
              take: 5,
              columns: [
                :name,
                { layout:                       { display_method: ->(row) { show_exist(row.behaviours.layout&.opts) } } },
                { after_action:                 { display_method: ->(row) { show_length(row.behaviours.after_action)               } } },
                { around_action:                { display_method: ->(row) { show_length(row.behaviours.around_action)              } } },
                { before_action:                { display_method: ->(row) { show_length(row.behaviours.before_action)              } } },
                { prepend_before_action:        { display_method: ->(row) { show_length(row.behaviours.prepend_before_action)      } } },
                { skip_before_action:           { display_method: ->(row) { show_length(row.behaviours.skip_before_action)         } } },
                { before_filter:                { display_method: ->(row) { show_length(row.behaviours.before_filter)              } } },
                { skip_before_filter:           { display_method: ->(row) { show_length(row.behaviours.skip_before_filter)         } } },
                { http_basic_authenticate_with: { display_method: ->(row) { show_exist(row.behaviours.http_basic_authenticate_with) } } },
                { http_basic_authenticate_with: { display_method: ->(row) { show_exist(row.behaviours.http_basic_authenticate_with) } } },
                { rescue_from:                  { display_method: ->(row) { show_length(row.behaviours.rescue_from)                } } },
                { helper_method:                { display_method: ->(row) { show_length(row.behaviours.helper_method)              } } },
                { helper:                       { display_method: ->(row) { show_length(row.behaviours.helper)                     } } },
                { layouts:                      { width: 150, display_method: ->(row) { row.behaviours.layout&.opts&.key?(:only) ? row.behaviours.layout.opts[:only].join(', ') : '' } } }
              ]
            },
            models: { skip: true }
          }
        }
      end

      it do
        log.structure(load_domain_model,
                      title: 'Rails Resources - Controller (Behaviours)',
                      line_width: 200, show_array_count: true,
                      graph: root_graph.merge(graph))
      end
    end

    context 'controllers (function)' do
      let(:graph) do
        {
          rails_structure: {
            controllers: {
              # pry_at: [:before_array],
              filter: ->(row) { row.exist },
              take: 5,
              columns: [
                :name,
                { class_name:       { display_method: ->(row) { row.functions.class_name                      } } },
                { module_name:      { display_method: ->(row) { row.functions.module_name                     } } },
                { class_full_name:  { display_method: ->(row) { row.functions.class_full_name                 } } },
                { attr_accessor:    { display_method: ->(row) { show_length(row.functions.attr_accessor)      } } },
                { attr_reader:      { display_method: ->(row) { show_length(row.functions.attr_reader)        } } },
                { attr_writer:      { display_method: ->(row) { show_length(row.functions.attr_writer)        } } },
                { klass:            { display_method: ->(row) { show_length(row.functions.klass)              } } },
                { instance_public:  { display_method: ->(row) { show_length(row.functions.instance_public)    } } },
                { instance_private: { display_method: ->(row) { show_length(row.functions.instance_private)   } } }
              ]
            },
            models: { skip: true }
          }
        }
      end

      it do
        log.structure(load_domain_model,
                      title: 'Rails Resources - Controller (Functions)',
                      line_width: 200, show_array_count: true,
                      graph: root_graph.merge(graph))
      end
    end

    context 'controllers (action)' do
      let(:graph) do
        {
          rails_structure: {
            controllers: {
              # pry_at: [:before_array],
              take: 50,
              title: 'Resource path - Rails Controllers',
              columns: [
                :file,
                # { class_name:       { display_method: ->(row) { row.functions.class_name                      } } },
                { class_full_name: { display_method: ->(row) { row.functions.class_full_name } } },
                'actions.route_name',
                'actions.action',
                'actions.uri_path',
                # 'actions.mime_match'
                'actions.verbs'
              ]
            },
            models: { skip: true }
          }
        }
      end

      # let(:graph) do
      #   {
      #     rails_structure: {
      #       controllers: {
      #           actions: {
      #             # pry_at: [:before_array],
      #             filter: ->(row) { row.exist },
      #             take: 5,
      #             columns: [
      #               :route_name,
      #               :action,
      #               :uri_path,
      #               :mime_match,
      #               { verbs: { display_method: -> (row) { row.verbs.join(',') } } }
      #             ]
      #           }
      #         }
      #     },
      #     models: { skip: true }
      #   }
      # end

      it do
        log.structure(load_domain_model,
                      title: 'Rails Resources - Controller (Functions)',
                      line_width: 200, show_array_count: true,
                      graph: root_graph.merge(graph))
      end
    end
  end

  context 'print dictionary' do
    let(:graph) do
      {
        dictionary: {
          items: {
            title: 'Dictionary',
            take: 5,
            columns: [
              :name,
              :type,
              :label,
              :segment,
              :model_count,
              { models: { width: 80, display_method: ->(row) { row.models.reject { |name| name == '__EFMigrationsHistory' || name.start_with?('asp_') }.join(', ') } } },
              :type_count,
              { types: { width: 40, display_method: ->(row) { row.types.join(', ') } } }
            ]
          }
        }
      }
    end

    it do
      log.structure(load_domain_model, title: 'Dictionary', line_width: 200, show_array_count: true, graph: root_graph.merge(graph))
    end
  end

  context 'print investigations' do
    let(:graph) do
      {
        investigate: {
          title: 'Investigations',
          issues: {
            take: 5,
            columns: [
              :step,
              :location,
              :key,
              { message: { width: 250 } }
            ]
          }
        }
      }
    end

    it do
      log.structure(load_domain_model,
                    title: 'Investigations',
                    line_width: 200,
                    show_array_count: true,
                    graph: root_graph.merge(graph))
    end
  end
end
