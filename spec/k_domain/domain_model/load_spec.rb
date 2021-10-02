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

      context '.investigate' do
        subject { instance.data.investigate }

        it { is_expected.not_to be_nil }

        context '.issues' do
          subject { instance.data.investigate.issues }

          it { is_expected.to be_an(Array) }

          context '.first' do
            subject { instance.data.investigate.issues.first }

            it do
              is_expected.to have_attributes(
                step: be_an(String),
                location: be_an(String),
                key: be_an(String),
                message: be_an(String)
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

              context '.first' do
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

        context '.erd_files' do
          subject { instance.data.domain.erd_files }

          it { is_expected.not_to be_nil }

          context '"sample"' do
            subject { sample }

            let(:sample) { instance.data.domain.erd_files.find { |erd| erd[:name] == 'sample' } }

            context '.source' do
              it do
                is_expected.to have_attributes(
                  name: be_an(String),
                  name_plural: be_an(String),
                  dsl_file: be_an(String),
                  source: have_attributes(
                    ruby: be_a(String),
                    public: be_a(String),
                    private: be_a(String),
                    all_methods: have_attributes(
                      klass: be_an(Array),
                      instance: be_an(Array),
                      instance_private: be_an(Array),
                      instance_public: be_an(Array)
                    )
                  )
                )
              end

              context 'source.methods.klass' do
                subject { sample.source.all_methods.klass.first }

                it do
                  is_expected.to have_attributes(
                    name: be_a(String),
                    scope: be_a(String),
                    class_method: eq(true),
                    arguments: be_a(String)
                  )
                end
              end

              context 'source.methods.instance' do
                subject { sample.source.all_methods.instance.first }

                it do
                  is_expected.to have_attributes(
                    name: be_a(String),
                    scope: be_a(String),
                    class_method: eq(false),
                    arguments: be_a(String)
                  )
                end
              end

              context 'source.methods.instance_private' do
                subject { sample.source.all_methods.instance_private.first }

                it do
                  is_expected.to have_attributes(
                    name: be_a(String),
                    scope: be_a(String),
                    class_method: eq(false),
                    arguments: be_a(String)
                  )
                end
              end

              context 'source.methods.instance_public' do
                subject { sample.source.all_methods.instance_public.first }

                it do
                  is_expected.to have_attributes(
                    name: be_a(String),
                    scope: be_a(String),
                    class_method: eq(false),
                    arguments: be_a(String)
                  )
                end
              end
            end

            context '.dsl' do
              subject { sample.dsl }

              it do
                is_expected.to have_attributes(
                  default_scope: be_an(String),
                  scopes: be_an(Array),
                  belongs_to: be_an(Array)
                )
              end

              context 'dsl.scopes' do
                subject { sample.dsl.scopes.first }

                it do
                  is_expected.to have_attributes(
                    name: be_a(String),
                    scope: be_a(String)
                  )
                end
              end

              context 'dsl.belongs_to' do
                subject { sample.dsl.belongs_to.first }

                it do
                  is_expected.to have_attributes(
                    name: be_a(String),
                    options: be_a(Hash),
                    raw_options: be_a(String)
                  )
                end
              end

              context 'dsl.has_one' do
                subject { sample.dsl.has_one.first }

                it do
                  is_expected.to have_attributes(
                    name: be_a(String),
                    options: be_a(Hash),
                    raw_options: be_a(String)
                  )
                end
              end

              context 'dsl.has_many' do
                subject { sample.dsl.has_many.first }

                it do
                  is_expected.to have_attributes(
                    name: be_a(String),
                    options: be_a(Hash),
                    raw_options: be_a(String)
                  )
                end
              end

              context 'dsl.has_and_belongs_to_many' do
                subject { sample.dsl.has_and_belongs_to_many.first }

                it do
                  is_expected.to have_attributes(
                    name: be_a(String),
                    options: be_a(Hash),
                    raw_options: be_a(String)
                  )
                end
              end

              context 'dsl.validate_on' do
                subject { sample.dsl.validate_on.first }

                it do
                  is_expected.to have_attributes(line: be_a(String))
                end
              end

              context 'dsl.validates_on' do
                subject { sample.dsl.validates_on.first }

                it do
                  is_expected.to have_attributes(
                    name: be_a(String),
                    raw_options: be_a(String)
                  )
                end
              end
            end
          end
        end

        context '.dictionary' do
          subject { instance.data.dictionary }

          it { is_expected.not_to be_nil }

          context '.first' do
            subject { instance.data.dictionary.items.first }

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
