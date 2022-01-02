# frozen_string_literal: true

RSpec.describe KDomain::Config::Configuration do
  include KLog::Logging

  let(:instance) { described_class.new }

  describe '#initialize' do
    subject { instance }

    it { is_expected.not_to be_nil }

    describe '.default_main_key' do
      subject { instance.default_main_key }

      it { is_expected.to be_nil }
    end

    describe '.default_traits' do
      subject { instance.default_traits }

      it { is_expected.not_to be_empty }
    end

    describe '.fallback_keys' do
      subject { instance.fallback_keys }

      it { is_expected.to be_empty }
    end

    describe '.models' do
      subject { instance.models }

      it { is_expected.to be_empty }
    end

    describe 'to_h' do
      subject { instance.to_h }

      it do
        is_expected.to include(
          default_main_key: nil,
          default_traits: %i[trait1 trait2 trait3],
          fallback_keys: [],
          models: []
        )
      end
    end
  end

  describe '#model' do
    subject { instance.models }

    before { instance.model(:xmen, main_key: :abc) }

    it { is_expected.not_to be_empty }

    it { is_expected.to include(KDomain::Config::Configuration::ConfigModel.new(:xmen, :abc, %i[trait1 trait2 trait3])) }

    describe '#find_model' do
      subject { instance.find_model(table_name) }

      let(:table_name) { :xmen }

      context 'when entity exists' do
        it { is_expected.to have_attributes(name: :xmen, main_key: :abc) }
      end

      context 'when entity does not exist' do
        let(:table_name) { :bad }

        it { is_expected.to have_attributes(name: :bad) }
      end
    end
  end

  describe '#fallback_key' do
    subject { instance.fallback_key(columns) }

    let(:columns) do
      [
        OpenStruct.new(name: :abc),
        OpenStruct.new(name: :xyz)
      ]
    end

    context 'when column name does not match fallback_key' do
      before { instance.fallback_keys = %i[aaa bbb ccc] }

      it { is_expected.to be_nil }
    end

    context 'when column name matches fallback_key' do
      before { instance.fallback_keys = %i[aaa bbb xyz ccc] }

      it { is_expected.to eq(:xyz) }
    end
  end
end
