# frozen_string_literal: true

RSpec.describe KDomain::RawDbSchema::Transform do
  let(:instance) { described_class.new(source_file)}
  let(:source_file) { 'spec/samples/raw_db_schema.rb' }
  let(:target_file) { 'spec/samples/output/schema.rb' }

  describe '#initialize' do
    context '.source_file' do
      subject { instance.source_file }
    
      it { is_expected.to eq(source_file) }
    end
    context '.template_file' do
      subject { instance.template_file }
    
      it { is_expected.to eq('lib/k_domain/raw_db_schema/template.rb') }
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
    subject { File.exist?(target_file) }

    before do
      instance.call
      instance.write_schema_loader(target_file)
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