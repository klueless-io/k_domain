# frozen_string_literal: true

RSpec.describe KDomain::RailsCodeExtractor::ExtractModel do
  include KLog::Logging

  let(:instance) { described_class.new(shim_loader) }
  let(:shim_loader) do
    result = KDomain::RailsCodeExtractor::ShimLoader.new
    result.register(:fake_module  , KDomain::Gem.resource('templates/fake_module_shims.rb'))
    result.register(:active_record, KDomain::Gem.resource('templates/active_record_shims.rb'))
    result
  end
  
  describe '#initialize' do
    subject { instance }

    it { is_expected.not_to be_nil }

    context '.shims_loaded' do
      subject { instance.shims_loaded }
      it { is_expected.to be_falsey }
    end

    context '.model' do
      subject { instance.model }

      it { is_expected.to be_nil }
    end

    context '.models' do
      subject { instance.models }
    
      it { is_expected.to be_empty }
    end
  end

  describe '#extract' do
    before { instance.extract(file) }

    let(:file) { 'spec/sample_input/models/sample.rb' }

    # let(:files) { Dir['spec/sample_input/models/*.rb'] }

    # Can only load sample once due and so all checks
    # are happening in this one it block
    it "check values" do
      # expect(instance.models.length).to eq(13)
      expect(instance.models.length).to eq(1)
      expect(instance.model).not_to be_nil

      sample = instance.model
      # target = '/Users/davidcruwys/dev/kgems/k_domain/spec/k_domain/rails_code_extractor/a.json'
      # File.write(target, JSON.pretty_generate(sample))
      sample = KUtil.data.to_open_struct(sample)

      expect(sample).to have_attributes(
        class_name: 'Sample',
        default_scope: have_attributes(block: '{ where(deleted: false) }'),
        scopes: have_attributes(length: 2),
        belongs_to: have_attributes(length: 3),
        has_one: have_attributes(length: 1),
        has_many: have_attributes(length: 6),
        has_and_belongs_to_many: have_attributes(length: 2),
        validate: have_attributes(length: 3),
        validates: have_attributes(length: 5)
      )

      nil_os = OpenStruct.new

      expect(sample.scopes.first).to have_attributes(
        name: :has_geo,
        opts: nil_os,
        block: '-> { where.not(longitude: nil, latitude: nil) }'
      )

      expect(sample.belongs_to.first).to have_attributes(
        name: :app_user,
        opts: nil_os,
      )
      expect(sample.has_one.first).to have_attributes(
        name: :user,
        opts: have_attributes(
          class_name: "User", 
          foreign_key: "id",
          primary_key: "sales_user_id"
        ),
        block: nil
      )
      expect(sample.has_many.first).to have_attributes(
        name: :user,
        opts: have_attributes(
          class_name: "User", 
          foreign_key: "id",
          primary_key: "sales_user_id"
        ),
        block: nil
      )
      expect(sample.has_and_belongs_to_many.first).to have_attributes(
        name: :trackers,
        opts: nil_os,
        block: "-> { uniq }"
      )
      expect(sample.validate.first).to have_attributes(
        names: [:ensure_valid_financial_year],
        opts: have_attributes(on: :create),
        block: nil
      )

      expect(sample.validates.first.name).to eq(:user)
      expect(sample.validates.first.opts[:presence].message).to eq('must exist')
    end
  end
end
