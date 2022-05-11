# frozen_string_literal: true

RSpec.describe KDomain::RawDbSchema::Transform do
  include_examples :domain_simple_settings

  def os(attributes)
    OpenStruct.new(attributes)
  end

  let(:instance) { described_class.new(db_schema_ruby_file, transform_filter) }
  let(:transform_filter) { os(active: 0, table: os(offset: 0, limit: 10)) }

  context 'with advanced schema', :skip_on_gha do
    include_examples :domain_advanced_settings
    include_examples :transform_db_schema

    it {
      db_transform
    }
  end

  describe '#initialize' do
    context '.source_file' do
      subject { instance.source_file }

      it { is_expected.to eq(db_schema_ruby_file) }
    end
    context '.template_file' do
      subject { instance.template_file }

      it { is_expected.to eq(File.expand_path('templates/load_schema.rb')) }
    end
  end

  context '.schema_loader' do
    subject { instance.schema_loader }

    context 'when #call not executed' do
      it { is_expected.to be_nil }
    end

    context 'when call executed' do
      before { instance.call }

      it { is_expected.not_to be_empty }
    end
  end

  describe '#write_schema_loader' do
    subject { File.exist?(schema_loader_file) }

    before do
      instance.call
      instance.write_schema_loader(schema_loader_file)
    end

    it { is_expected.to be_truthy }
  end

  describe '#write_json' do
    subject { File.exist?(db_schema_json_file) }

    before do
      instance.call
      instance.write_json(db_schema_json_file)
    end

    it { is_expected.to be_truthy }
  end

  context '.schema' do
    subject { instance.schema }

    context 'when #call not executed' do
      it { is_expected.to be_nil }
    end

    context 'when call executed' do
      before { instance.call }

      it { is_expected.not_to be_empty }

      describe '#filtered' do
        subject { instance.schema[:tables].map { |table| table[:name] } }

        context 'when all tables' do
          it { is_expected.to have_attributes(length: 21) }
        end

        context 'when inactive, offset: 0, limit: 1' do
          let(:transform_filter) { os(active: 0, table: os(offset: 0, limit: 1)) }

          it { is_expected.to have_attributes(length: 21) }
        end

        context 'when active, offset: 0, limit: 1' do
          let(:transform_filter) { os(active: 1, table: os(offset: 0, limit: 1)) }

          it { is_expected.to eq(%w[__EFMigrationsHistory]) }
        end

        context 'when active, offset: 1, limit: 2' do
          let(:transform_filter) { os(active: 1, table: os(offset: 1, limit: 2)) }

          it { is_expected.to eq(%w[samples app_users]) }
        end
      end
    end
  end
end
