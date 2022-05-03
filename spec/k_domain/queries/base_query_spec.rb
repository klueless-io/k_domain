# frozen_string_literal: true

RSpec.describe KDomain::Queries::BaseQuery do
  include KLog::Logging

  include_examples :load_domain_model

  let(:instance) { described_class.new(load_domain_model) }

  describe '#initialize' do
    context '.domain_model' do
      subject { instance.domain_model }

      it { is_expected.not_to be_nil }
    end
  end

  # context 'when using simple DOM' do

  # end

  # context 'when using advanced DOM', :skip_on_gha do
  #   let(:load_domain_model_file) { 'spec/example_domain/advanced/output/domain_model.json' }
  # end
end
