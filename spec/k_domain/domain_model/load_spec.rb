# frozen_string_literal: true

RSpec.describe KDomain::DomainModel::Load do
  let(:instance) { described_class.new(source_file) }

  let(:source_file) { 'spec/sample_output/domain_model/domain_model.json' }

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

      context '.database' do
        subject { instance.data.database }

        it { is_expected.not_to be_nil }
      end

      # TODO
      # context '.investigate' do
      #   subject { instance.data.investigate }

      #   it { is_expected.not_to be_nil }
      # end

      context '.domain' do
        subject { instance.data.domain }

        it { is_expected.not_to be_nil }

        context '.models' do
          subject { instance.data.domain.models }

          it { is_expected.not_to be_nil }

          context '.models::first' do
            subject { instance.data.domain.models.first }

            it do
              is_expected.to have_attributes(
                name: be_an(String),
                name_plural: be_an(String),
                table_name: be_an(String),
                pk: have_attributes(
                  name: be_an(String),
                  type: be_an(String),
                  exist: eq(true)
                ),
                erd_location: have_attributes(
                  file: be_an(String),
                  exist: eq(false),
                  state: be_an(Array)
                ),
                columns: be_an(Array)
              )
            end

            context '.columns' do
              subject { instance.data.domain.models.first.columns }

              it { is_expected.not_to be_nil }

              context '.columns::first' do
                subject { instance.data.domain.models.first.columns.first }

                it do
                  is_expected.to have_attributes(
                    name: be_an(String),
                    name_plural: be_an(String),
                    type: be_an(Symbol),
                    precision: be_nil,
                    scale: be_nil,
                    default: be_nil,
                    null: be_nil,
                    limit: be_nil,
                    array: be_nil,
                    structure_type: be_an(Symbol),
                    foreign_key: eq(false),
                    foreign_table: be_an(String),
                    foreign_table_plural: be_an(String)
                  )
                end
              end
            end
          end
        end

        context '.dictionary' do
          subject { instance.data.domain.dictionary }

          it { is_expected.not_to be_nil }

          context '.dictionary::first' do
            subject { instance.data.domain.dictionary.first }

            it do
              is_expected.to have_attributes(
                name: be_an(String),
                type: be_an(String),
                label: be_an(String),
                segment: be_an(String),
                models: be_an(Array),
                model_count: be_an(Integer),
                types: be_an(Array),
                type_count: be_an(Integer)
              )
            end
          end
        end
      end
    end
  end
end
