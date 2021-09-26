# frozen_string_literal: true

RSpec.describe KDomain do
  it 'has a version number' do
    expect(KDomain::VERSION).not_to be nil
  end

  it 'has a standard error' do
    expect { raise KDomain::Error, 'some message' }
      .to raise_error('some message')
  end
end
