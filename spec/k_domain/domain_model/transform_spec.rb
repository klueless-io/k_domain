# frozen_string_literal: true

RSpec.describe KDomain::DomainModel::Transform do
  include_examples :transform_db_schema

  let(:db_schema)                 { db_transform }

  let(:instance)                  do
    described_class.new(
      db_schema: db_schema,
      target_file: target_file,
      target_step_file: target_step_file,
      erd_path: erd_path
    )
  end

  let(:source_file)               { 'spec/sample_input/raw_db_schema.rb' }
  let(:erd_path)                  { File.expand_path('spec/sample_input/models') }

  let(:target_file)               { 'spec/sample_output/domain_model/domain_model.json' }
  let(:target_step_file)          { 'spec/sample_output/domain_model/%{step}.json' }

  context 'complex erd' do
    let(:raw_db_schema_file)      { '/Users/davidcruwys/dev/printspeak/printspeak-master/db/schema.rb' }
    let(:raw_db_schema_json_file) { 'spec/sample_output/printspeak/schema.json' }
    let(:erd_path)                { '/Users/davidcruwys/dev/printspeak/printspeak-master/app/models' }

    let(:source_file)             { target_file }
    let(:target_file)             { 'spec/sample_output/printspeak/domain_model.json' }
    let(:target_step_file)        { 'spec/sample_output/printspeak/%{step}.json' }

    # fit {
    #   db_transform
    #   instance.call
    # }
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
            models: be_empty,
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
            meta: be_empty
          )
        end
      end

      context '.rails_resource' do
        subject { instance.domain_data[:rails_resource] }

        it do
          is_expected.to include(
            models: be_empty,
            controllers: be_empty
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

    context '.attach_database' do
      subject { instance.domain_data[:database] }

      it do
        is_expected.not_to include(
          tables: be_empty,
          indexes: be_empty,
          foreign_keys: be_empty,
          meta: be_empty
        )
      end
    end

    context '.attach_models' do
      subject { instance.domain_data[:domain][:models] }

      it { is_expected.not_to be_empty }
      # fit { puts JSON.pretty_generate(subject) }
    end

    context '.attach_columns' do
      subject { instance.domain_data[:domain][:models].first[:columns] }

      it { is_expected.not_to be_empty }
    end

    # context '.attach_erd_files' do
    #   subject { instance.domain_data[:domain][:erd_files] }

    #   it { is_expected.not_to be_empty }
    # end

    context '.rails_resource' do
      context '.models' do
        subject { instance.domain_data[:rails_resource][:models] }

        it { is_expected.not_to be_empty }
      end
      context '.controllers' do
        subject { instance.domain_data[:rails_resource][:controllers] }

        it { is_expected.to be_empty }
      end
    end

    context '.rails_structure' do
      context '.models' do
        subject { instance.domain_data[:rails_structure][:models] }

        # it { is_expected.not_to be_empty }
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
