# frozen_string_literal: true

# Load domain model schema
RSpec.shared_examples :load_domain_model do
  let(:load_domain_model_file) { 'spec/sample_output/domain_model/domain_model.json' }

  let(:load_domain_model) do
    loader = KDomain::DomainModel::Load.new(load_domain_model_file)
    loader.call
    loader.data
  end
end
