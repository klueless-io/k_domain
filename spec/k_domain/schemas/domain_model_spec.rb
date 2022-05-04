# frozen_string_literal: true

RSpec.describe 'KDomain::Schemas' do
  include KLog::Logging

  context 'when using advanced DOM', :skip_on_gha do
    before(:context) do
      # load the json model once
      loader = KDomain::DomainModel::Load.new('spec/example_domain/advanced/output/domain_model.json')
      loader.call
      loader.data
    end

    let(:target_file) { 'spec/example_domain/to_hash/advanced_domain_model.json' }

    # fit {
    #   File.write(target_file, JSON.pretty_generate(@data.to_h))
    # }
  end
end
