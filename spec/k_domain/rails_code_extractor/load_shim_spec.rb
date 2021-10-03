# frozen_string_literal: true

RSpec.describe KDomain::RailsCodeExtractor::LoadShim do
  let(:instance) { described_class.new }

  describe '#initialize' do
    subject { instance }

    it { is_expected.not_to be_nil }

    context '.shim_files' do
      subject { instance.shim_files }

      it { is_expected.to be_empty }
    end
  end

  describe '#register' do
    before { instance.register(name, file) }

    context 'when file not found' do
      let(:name) { :david }
      let(:file) { 'david.rb' }

      context '.shim_files' do
        subject { instance.shim_files }

        it do
          is_expected.to include({ name: :david, file: 'david.rb', exist: false })
        end
      end
    end

    context 'when file found' do
      context '.shim_files' do
        subject { instance.shim_files }

        context 'file: :active_record_shim' do
          let(:name) { :active_record }
          let(:file) { KDomain::Gem.resource('templates/active_record_shims.rb') }

          it do
            is_expected.to include({ name: :active_record, file: end_with('templates/active_record_shims.rb'), exist: true })
          end
        end
      end

      context '.shim_files' do
        subject { instance.shim_files }

        context 'file: :fake_module_shims' do
          let(:name) { :fake_module }
          let(:file) { KDomain::Gem.resource('templates/fake_module_shims.rb') }

          it do
            is_expected.to include({ name: :fake_module, file: end_with('templates/fake_module_shims.rb'), exist: true })
          end
        end
      end
    end
  end
end
