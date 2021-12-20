# frozen_string_literal: true

RSpec.describe KDomain::RawDbSchema::Transform do
  include_examples :domain_simple_settings

  let(:instance) { described_class.new(db_schema_ruby_file) }

  context 'with advanced schema' do
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
    end
  end
end
