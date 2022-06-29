# frozen_string_literal: true

RSpec.describe KDomain::DomainModel::BuildRichModels do
  include_examples :domain_simple_settings
  include_examples :load_domain_model

  def os(attributes)
    OpenStruct.new(attributes)
  end

  let(:instance) { described_class.new(domain_model: load_domain_model, target_folder: json_model_folder) }

  # loader = KDomain::DomainModel::Load.new('spec/example_domain/advanced/output/main_dataset.json')
  # loader.call

  # @query = KDomain::Queries::DomainModelQuery.new(loader.data)
  # @mapper = KDomain::Map::DomainModalToH.new(@query)
  # let(:target_models_folder) { 'spec/example_domain/advanced/output/models' }

  describe '#call' do
    subject { instance.call }
    it do
      subject
    end
  end

  # let(:transform_filter) { os(active: 0, table: os(offset: 0, limit: 10)) }
  context 'advanced domain' do
    include_examples :domain_advanced_settings

    describe '#call' do
      subject { instance.call }
      it do
        subject
      end
    end
  end
end
