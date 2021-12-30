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
          let(:file) { KDomain::Gem.resource('templates/rails/active_record.rb') }

          it do
            is_expected.to include({ name: :active_record, file: end_with('templates/rails/active_record.rb'), exist: true })
          end
        end
      end

      # context '.shim_files' do
      #   subject { instance.shim_files }

      #   context 'file: :custom_module_shims' do
      #     let(:name) { :custom_module }
      #     let(:file) { KDomain::Gem.resource('templates/custom_module_shims.rb') }

      #     it do
      #       is_expected.to include({ name: :custom_module, file: end_with('templates/custom_module_shims.rb'), exist: true })
      #     end
      #   end
      # end
    end
  end

  describe '#call' do
    before do
      instance.register(:active_record, KDomain::Gem.resource('templates/ruby_code_extractor/attach_class_info.rb'))
      instance.register(:active_record, KDomain::Gem.resource('templates/ruby_code_extractor/behaviour_accessors.rb'))
      instance.register(:active_record, KDomain::Gem.resource('templates/rails/active_record.rb'))
      instance.register(:active_record, KDomain::Gem.resource('templates/custom/model_interceptors.rb'))
      instance.register(:bad , 'bad_shims.rb')
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
