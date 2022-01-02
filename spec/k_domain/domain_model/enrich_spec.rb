# frozen_string_literal: true

RSpec.describe KDomain::DomainModel::Load do
  let(:instance) { described_class.new(source_file) }

  let(:source_file) { 'spec/example_domain/simple/output/domain_model/domain_model.json' }
  # let(:source_file) { '/Users/davidcruwys/dev/kgems/k_domain/spec/example_domain/advanced/output/domain_model.json' }

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

      context '.database' do
        subject { instance.data.database }

        it { is_expected.not_to be_nil }
      end

      context '.rails_resource' do
        subject { instance.data.rails_resource }

        it { is_expected.not_to be_nil }

        context '.models.first' do
          subject { instance.data.rails_resource.models.first }

          it do
            is_expected.to have_attributes(
              model_name: be_a(String),
              table_name: be_a(String),
              file: be_a(String),
              exist: eq(false),
              state: be_a(String)
            )
          end
        end
      end

      context '.rails_structure' do
        subject { instance.data.rails_structure }

        it { is_expected.not_to be_nil }

        context '.models.first' do
          subject { instance.data.rails_structure.models.first }

          it do
            is_expected.to have_attributes(
              model_name: be_a(String),
              table_name: be_a(String),
              file: be_a(String),
              exist: eq(false),
              state: be_a(String),
              code: be_a(String),
              behaviours: be_a(KDomain::Schemas::RailsStructure::ModelBehaviours),
              functions: be_a(KDomain::Schemas::RailsStructure::Functions)
            )
          end
        end

        context '.model#sample' do
          subject { sample }

          let(:sample) { instance.data.rails_structure.models.find { |m| m.model_name == 'sample' } }

          it do
            is_expected.to have_attributes(
              model_name: be_a(String),
              table_name: be_a(String),
              file: be_a(String),
              exist: eq(true),
              state: be_a(String),
              code: be_a(String),
              behaviours: be_a(KDomain::Schemas::RailsStructure::ModelBehaviours),
              functions: be_a(KDomain::Schemas::RailsStructure::Functions)
            )
          end

          context '.behaviours' do
            subject { sample.behaviours }

            it do
              is_expected.to have_attributes(
                class_name: 'Sample',
                default_scope: have_attributes(block: '{ where(deleted: false) }'),
                scopes: have_attributes(length: 2),
                belongs_to: have_attributes(length: 3),
                has_one: have_attributes(length: 1),
                has_many: have_attributes(length: 6),
                has_and_belongs_to_many: have_attributes(length: 2),
                validate: have_attributes(length: 3),
                validates: have_attributes(length: 5),
                attr_accessor: have_attributes(length: 2),
                attr_reader: have_attributes(length: 1),
                attr_writer: have_attributes(length: 3)
              )
            end
          end

          context '.functions' do
            subject { sample.functions }

            it do
              is_expected.to have_attributes(
                class_name: 'Sample',
                module_name: '',
                class_full_name: 'Sample',
                attr_accessor: have_attributes(length: 2),
                attr_reader: have_attributes(length: 1),
                attr_writer: have_attributes(length: 3),
                klass: have_attributes(length: 3),
                instance_public: have_attributes(length: 3),
                instance_private: have_attributes(length: 3)
              )
            end
          end
        end

        context '.controllers.first' do
          subject { instance.data.rails_structure.controllers.first }

          it { is_expected.not_to be_nil }
        end
      end

      context '.dictionary' do
        subject { instance.data.dictionary }

        it { is_expected.not_to be_nil }

        context '.first' do
          subject { instance.data.dictionary.items.first }

          it do
            is_expected.to have_attributes(
              name: be_a(String),
              type: be_a(String),
              label: be_a(String),
              segment: be_a(String),
              models: be_a(Array),
              model_count: be_a(Integer),
              types: be_a(Array),
              type_count: be_a(Integer)
            )
          end
        end
      end

      context '.investigate' do
        subject { instance.data.investigate }

        it { is_expected.not_to be_nil }

        context '.issues' do
          subject { instance.data.investigate.issues }

          it { is_expected.to be_a(Array) }

          context '.first' do
            subject { instance.data.investigate.issues.first }

            it do
              is_expected.to have_attributes(
                step: be_a(String),
                location: be_a(String),
                key: be_a(String),
                message: be_a(String)
              )
            end
          end
        end
      end

      context '.domain' do
        subject { instance.data.domain }

        it { is_expected.not_to be_nil }

        context '.models' do
          subject { instance.data.domain.models }

          it { is_expected.not_to be_nil }

          context '.first' do
            subject { instance.data.domain.models.first }

            it do
              is_expected.to have_attributes(
                name: be_a(String),
                name_plural: be_a(String),
                table_name: be_a(String),
                pk: have_attributes(
                  name: be_a(String),
                  type: be_a(String),
                  exist: eq(true)
                ),
                main_key: be_nil,
                columns: be_a(Array)
              )
            end

            context 'when entity has configured model' do
              before do
                KDomain.reset
                KDomain.configure do |config|
                  config.model(:__EFMigrationsHistory, main_key: :xmen)
                end
              end

              describe '.config' do
                subject { instance.data.domain.models.first.config }

                it { is_expected.to have_attributes(name: :__EFMigrationsHistory, main_key: :xmen) }
              end

              describe '.main_key' do
                subject { instance.data.domain.models.first.main_key }

                it { is_expected.to eq(:xmen) }
              end
            end

            describe '.main_key' do
              subject { instance.data.domain.models.first.main_key }

              context 'when fallback key matches a valid field' do
                before do
                  KDomain.reset
                  KDomain.configure do |config|
                    config.fallback_keys = %i[ProductVersion]
                  end
                end

                it { is_expected.to eq(:ProductVersion) }
              end
            end

            describe '.columns' do
              subject { instance.data.domain.models.first.columns }

              it { is_expected.not_to be_nil }

              context '.first' do
                subject { instance.data.domain.models.first.columns.first }

                it do
                  is_expected.to have_attributes(
                    name: be_a(String),
                    name_plural: be_a(String),
                    type: be_a(Symbol),
                    precision: be_nil,
                    scale: be_nil,
                    default: be_nil,
                    null: be_nil,
                    limit: be_nil,
                    array: be_nil
                    # structure_type: be_a(Symbol),
                    # foreign_key: eq(false),
                    # foreign_table: be_a(String),
                    # foreign_table_plural: be_a(String)
                  )
                end
              end
            end
          end
        end
      end
    end
  end
end
