# frozen_string_literal: true

RSpec.describe KDomain::DomainModel::Transform do
  include_examples :domain_simple_settings
  include_examples :transform_db_schema

  let(:db_schema)                 { db_transform }

  let(:instance)                  do
    described_class.new(
      db_schema: db_schema,
      target_file: target_file,
      target_step_file: target_step_file,
      model_path: model_path,
      controller_path: controller_path,
      route_path: route_path
    )
  end
  
  let(:target_file)               { 'spec/example_domain/simple/output/domain_model/domain_model.json' }
  let(:target_step_file)          { 'spec/example_domain/simple/output/domain_model/%{step}.json' }

  context 'advanced domain' do
    include_examples :domain_advanced_settings

    let(:target_file)             { 'spec/example_domain/advanced/output/domain_model.json' }
    let(:target_step_file)        { 'spec/example_domain/advanced/output/%{step}.json' }

    it {
      db_transform
      instance.call
    }
  end

  fdescribe '#initialize' do
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

        it { is_expected.to be_empty }
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
