# frozen_string_literal: true

RSpec.describe KDomain::DomainModel::Transform do
  include_examples :domain_simple_settings
  include_examples :transform_db_schema

  def os(attributes)
    OpenStruct.new(attributes)
  end

  let(:transform_filter) { os(active: 0, table: os(offset: 0, limit: 10)) }

  let(:db_schema) { db_transform }

  let(:instance) do
    described_class.new(
      db_schema: db_schema,
      target_file: target_file,
      target_step_file: target_step_file,
      model_path: model_path,
      controller_path: controller_path,
      route_path: route_path,
      shim_loader: shim_loader
    )
  end

  let(:shim_loader) do
    shim_loader = KDomain::RailsCodeExtractor::ShimLoader.new
    # Shims to attach generic class_info writers
    shim_loader.register(:attach_class_info           , KDomain::Gem.resource('templates/ruby_code_extractor/attach_class_info.rb'))
    shim_loader.register(:behaviour_accessors         , KDomain::Gem.resource('templates/ruby_code_extractor/behaviour_accessors.rb'))

    # Shims to support standard active_record DSL methods
    shim_loader.register(:active_record               , KDomain::Gem.resource('templates/rails/active_record.rb'))
    shim_loader.register(:action_controller           , KDomain::Gem.resource('templates/rails/action_controller.rb'))

    # Shims to support application specific [module, class, method] implementations for suppression and exception avoidance
    # shim_loader.register(:app_active_record         , KDomain::Gem.resource('templates/custom/active_record.rb'))
    shim_loader.register(:app_model_interceptors      , KDomain::Gem.resource('templates/custom/model_interceptors.rb'))
    shim_loader.register(:app_model_interceptors      , KDomain::Gem.resource('templates/custom/controller_interceptors.rb'))
    shim_loader
  end

  let(:target_file)               { 'spec/example_domain/simple/output/domain_model/domain_model.json' }
  let(:target_step_file)          { 'spec/example_domain/simple/output/domain_model/%{step}.json' }

  context 'advanced domain' do
    include_examples :domain_advanced_settings

    let(:target_file)             { 'spec/example_domain/advanced/output/domain_model.json' }
    let(:target_step_file)        { 'spec/example_domain/advanced/output/%{step}.json' }

    xit do
      db_transform
      instance.call
    end
  end

  describe '#initialize' do
    context '.db_schema' do
      subject { instance.db_schema }

      it { is_expected.to eq(db_schema) }
    end
    context '.domain_data' do
      subject { instance.domain_data }

      it { is_expected.not_to be_nil }

      context '.domain' do
        subject { instance.domain_data[:domain] }

        it do
          is_expected.to include(
            models: be_empty
            # erd_files: be_empty # replace this with behaviours and functions
          )
        end
      end

      context '.database' do
        subject { instance.domain_data[:database] }

        it do
          is_expected.to include(
            tables: be_empty,
            indexes: be_empty,
            foreign_keys: be_empty,
            views: be_empty,
            meta: be_empty
          )
        end
      end

      context '.rails_resource' do
        subject { instance.domain_data[:rails_resource] }

        it do
          is_expected.to include(
            models: be_empty,
            routes: be_empty
          )
        end
      end

      context '.rails_structure' do
        subject { instance.domain_data[:rails_structure] }

        it do
          is_expected.to include(
            models: be_empty,
            controllers: be_empty
          )
        end
      end

      context '.dictionary' do
        subject { instance.domain_data[:dictionary] }

        it { is_expected.to include(items: be_empty) }
      end

      context '.investigate' do
        subject { instance.domain_data[:investigate] }

        it { is_expected.to include(issues: be_empty) }
      end
    end
  end

  describe '#call' do
    before { instance.call }

    context '.database' do
      subject { instance.domain_data[:database] }

      it do
        is_expected.not_to include(
          tables: be_empty,
          indexes: be_empty,
          foreign_keys: be_empty,
          meta: be_empty
        )
        # The basic sample does not include any views
        # views: be_empty,
      end
    end

    context '.domain' do
      context '.models' do
        subject { instance.domain_data[:domain][:models] }

        it { is_expected.not_to be_empty }
      end

      context '.columns' do
        subject { instance.domain_data[:domain][:models].first[:columns] }

        it { is_expected.not_to be_empty }
      end
    end

    context '.rails_resource' do
      context '.models' do
        subject { instance.domain_data[:rails_resource][:models] }

        it { is_expected.not_to be_empty }
      end
      context '.routes' do
        subject { instance.domain_data[:rails_resource][:routes] }

        it { is_expected.not_to be_empty }
      end
    end

    context '.rails_structure' do
      context '.models' do
        subject { instance.domain_data[:rails_structure][:models] }

        it { is_expected.not_to be_empty }
      end
      context '.controllers' do
        subject { instance.domain_data[:rails_structure][:controllers] }

        it { is_expected.not_to be_empty }
      end
    end

    context '.dictionary->items' do
      subject { instance.domain_data[:dictionary][:items] }

      it { is_expected.not_to be_empty }
    end

    context '.investigate->issues' do
      subject { instance.domain_data[:investigate][:issues] }

      it { is_expected.not_to be_empty }
    end
  end
end
