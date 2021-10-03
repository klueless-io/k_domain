# frozen_string_literal: true

RSpec.describe KDomain::RailsCodeExtractor::ShimLoader do
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

  describe '#call' do
    before do
      instance.register(:active_record, KDomain::Gem.resource('templates/active_record_shims.rb'))
      instance.register(:fake_module  , KDomain::Gem.resource('templates/fake_module_shims.rb'))
      instance.register(:bad  , 'bad_shims.rb')
    end

    context 'before call' do
      it do
        expect(defined?(ActiveRecord)).to be_falsey
        expect(defined?(Rails)).to be_falsey
        expect(defined?(ActsAsCommentable)).to be_falsey
      end

      context 'after call' do
        before { instance.call }

        it do
          expect(defined?(ActiveRecord)).to be_truthy
          expect(defined?(ActiveRecord::Base)).to be_truthy
          expect(defined?(Rails)).to be_truthy
          expect(defined?(ActsAsCommentable)).to be_truthy
        end
      end
    end
  
  end
end
