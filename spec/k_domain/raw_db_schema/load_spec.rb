# frozen_string_literal: true

RSpec.describe KDomain::RawDbSchema::Load do
  let(:instance) { described_class.new(source_file) }

  def os(attributes)
    OpenStruct.new(attributes)
  end

  let(:transform_filter) { os(active: 0, table: os(offset: 0, limit: 10)) }

  let(:db_schema_ruby_file)       { 'spec/example_domain/simple/input/schema.rb' }
  let(:db_schema_json_file)       { 'spec/example_domain/simple/output/raw_db_schema/schema.json' }
  let(:schema_loader_file)        { 'spec/example_domain/simple/output/raw_db_schema/schema_loader.rb' }

  context 'with existing db_schema.json' do
    include_examples :transform_db_schema

    before { db_transform }

    let(:source_file) { db_schema_json_file }

    describe '#initialize' do
      context '.source_file' do
        subject { instance.source_file }

        it { is_expected.not_to be_empty }
      end

      context '.data' do
        subject { instance.data }

        it { is_expected.to be_nil }
      end

      context '.to_h' do
        subject { instance.to_h }

        it { is_expected.to be_nil }
      end
    end

    describe '#call' do
      before { instance.call }

      context '.to_h' do
        subject { instance.to_h }

        it { is_expected.not_to be_nil }
      end

      context '.data' do
        subject { instance.data }

        it { is_expected.not_to be_nil }

        context '.meta' do
          subject { instance.data.meta }

          it { is_expected.not_to be_nil }

          it do
            is_expected.to have_attributes(
              rails: 4,
              db_info: have_attributes(
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
                rails_schema: have_attributes(primary_key: 'MigrationId')
              )
            end
          end
        end
      end
    end
  end
end
