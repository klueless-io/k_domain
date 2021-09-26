# frozen_string_literal: true

RSpec.describe KDomain::DomainModel::Transform do
  include_examples :transform_db_schema

  let(:instance) { described_class.new(db_schema)}
  let(:source_file) { 'spec/samples/raw_db_schema.rb' }
  let(:target_file) { 'spec/samples/output/schema.rb' }

  let(:db_schema) { db_transform }

  describe '#initialize' do
    context '.db_schema' do
      subject { instance.db_schema }
    
      it { is_expected.to eq(db_schema) }
    end
    context '.domain_data' do
      subject { instance.domain_data }
    
      it { is_expected.not_to be_nil }

      context '.domain' do
        subject { instance.domain_data[:domain] }
      
        it do
          is_expected.to include(
            models: be_empty,
            erd_files: be_empty,
            dictionary: be_empty
          )
        end
      end

      context '.database' do
        subject { instance.domain_data[:database] }
      
        it { is_expected.to be_empty }
      end

      context '.investigate' do
        subject { instance.domain_data[:investigate] }
      
        it { is_expected.to include(investigations: be_empty) }
      end
    end
  end

  describe '#call' do
    let(:steps) { [] }
    context 'step1' do
      before { instance.call(*steps) }

      context '.attach_database' do
        subject { instance.domain_data[:database] }

        let(:steps) { %i[attach_database] }
      
        it { is_expected.not_to be_empty }

        context '.attach_models' do
          subject { instance.domain_data[:domain][:models] }
  
          let(:steps) do
            %i[
              attach_database
              attach_models
            ]
          end
        
          # fit { is_expected.not_to be_empty }
          # fit { puts JSON.pretty_generate(subject) }
        end
      end
    end
  end

    # context '.target_ruby_class' do
  #   subject { instance.target_ruby_class }

  #   context 'when #call not executed' do
  #     it { is_expected.to be_nil }
  #   end

  #   context 'when call executed' do
  #     before { instance.call }

  #     it { is_expected.not_to be_empty }
  #   end
  # end
end
