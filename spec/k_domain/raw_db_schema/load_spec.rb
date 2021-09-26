# frozen_string_literal: true

RSpec.describe KDomain::RawDbSchema::Load do
  let(:instance) { described_class.new(source_file) }
  
  # Setup transformed JSON before load be used
  let(:transformer) { KDomain::RawDbSchema::Transform.new(raw_db_schema_file) }
  let(:transform) do
    transformer.call
    transformer.write_json(raw_db_schema_json_file)
    transformer.json
  end
  let(:raw_db_schema_file) { 'spec/samples/raw_db_schema.rb' }
  let(:raw_db_schema_json_file) { 'spec/samples/raw_db_schema.json' }

  context 'with existing db_schema.json' do
    before { transform }

    let(:source_file) { raw_db_schema_json_file }

    describe '#initialize' do
      context '.source_file' do
        subject { instance.source_file }
      
        it { is_expected.not_to be_empty }
      end
  
      context '.data' do
        subject { instance.data }
      
        it { is_expected.to be_nil }
      end
    end

    describe '#call' do
      before { instance.call }

      context '.data' do
        subject { instance.data }
      
        it { is_expected.not_to be_nil }

        context '.meta' do
          subject { instance.data.meta }
        
          it { is_expected.not_to be_nil }

          it do
            is_expected.to have_attributes(
              rails: 4,
              database: have_attributes(
                type: 'postgres',
                version: be_nil,
                extensions: be_an(Array)
              ),
              unique_keys: be_an(Array)
            )
          end
        end

        context '.indexes' do
          subject { instance.data.indexes }
        
          it { is_expected.to be_an(Array) }

          context '.first' do
            subject { instance.data.indexes.first }

            it do
              is_expected.to have_attributes(
                name: be_an(String),
                using: be_an(String),
                fields: be_an(Array)
              )
            end
          end
        end

        context '.foreign_keys' do
          subject { instance.data.foreign_keys }
        
          it { is_expected.to be_an(Array) }

          context '.first' do
            subject { instance.data.foreign_keys.first }

            it do
              is_expected.to have_attributes(
                left: be_an(String),
                right: be_an(String)
              )
            end
          end
        end

        context '.tables' do
          subject { instance.data.tables }
        
          it { is_expected.to be_an(Array) }

          context '.first' do
            subject { instance.data.tables.first }

            it do
              is_expected.to have_attributes(
                name: be_an(String),
                columns: be_an(Array),
                indexes: be_an(Array),
                rails_schema: have_attributes(primary_key: "MigrationId")
              )
            end
          end
        end
      end
    end
  end
end
