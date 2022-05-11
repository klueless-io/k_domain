# frozen_string_literal: true

RSpec.describe KDomain::Queries::DomainModelQuery do
  include KLog::Logging

  shared_examples :log_structure do |filters = {}|
    let(:query) { instance.query(**filters) }
    let(:graph) do
      {
        models: {
          title: 'Models',
          take: 20,
          columns: [
            :name,
            :name_plural,
            :table_name,
            :type,
            { pk:               { display_method: ->(row) { row.pk.name                            } } },
            { pk_type:          { display_method: ->(row) { row.pk.type                            } } },
            { pk_exist:         { display_method: ->(row) { row.pk.exist                           } } },
            { column_count:     { display_method: ->(row) { show_length(row.columns)               } } },
            { for_data:         { display_method: ->(row) { show_length(row.columns_data)          } } },
            { for_primary:      { display_method: ->(row) { show_length(row.columns_primary)       } } },
            { for_fk:           { display_method: ->(row) { show_length(row.columns_foreign_key)   } } },
            { for_poly_fy:      { display_method: ->(row) { show_length(row.columns_foreign_type)  } } },
            { for_timestamp:    { display_method: ->(row) { show_length(row.columns_timestamp)     } } },
            { for_deleted_at:   { display_method: ->(row) { show_length(row.columns_deleted_at)    } } },
            { for_virtual:      { display_method: ->(row) { show_length(row.columns_virtual)       } } },
            { for_data_foreign: { display_method: ->(row) { show_length(row.columns_data_foreign)  } } },
            { column_names:     { width: 150, display_method: ->(row) { row.columns.take(12).map(&:name).join(', ') } } }
          ]
        }
      }
    end

    it do
      log.structure({ models: query },
                    title: 'Models',
                    line_width: 200,
                    show_array_count: true, graph: graph)
    end
  end

  context 'when using simple DOM' do
    include_examples :domain_simple_settings
    include_examples :load_domain_model

    let(:instance) { described_class.new(load_domain_model) }

    describe '#initialize' do
      context '.domain_model' do
        subject { instance.domain_model }

        it { is_expected.not_to be_nil }
      end
    end

    describe '#all' do
      it { expect(instance.all.count).to eq 21 }
    end

    describe '#query' do
      let(:filters) { {} }

      context 'when filter for models with associated ruby file' do
        let(:filters) { { ruby: true } }

        it { expect(instance.query(ruby: true)).to all(have_attributes(ruby?: true)) }
      end

      context 'when filter for model without ruby file' do
        let(:filters) { { ruby: false } }

        it { expect(instance.query(ruby: false)).to all(have_attributes(ruby?: false)) }
      end

      context 'when filter for models with primary key' do
        let(:filters) { { pk: true } }

        it { expect(instance.query(pk: true)).to all(have_attributes(pk?: true)) }
      end

      context 'when filter for models without primary key' do
        let(:filters) { { pk: false } }

        it { expect(instance.query(pk: false)).to all(have_attributes(pk?: false)) }
      end
    end
  end

  context 'when using advanced DOM', :skip_on_gha do
    include_examples :domain_simple_settings
    include_examples :load_domain_model

    let(:instance) { described_class.new(load_domain_model) }
    let(:query) { instance.query(**filters) }

    let(:log_structure) { log.structure({ models: query }, title: 'Models', line_width: 200, show_array_count: true, graph: graph) }

    describe '#all' do
      let(:query) { instance.all }

      it_behaves_like :log_structure
    end

    # Query models found on the domain model
    # by
    #   has ruby file
    #   has primary key
    #   column count
    #   data column count
    #   foreign key column count
    #   has standard timestamp columns
    #   has created at
    #   has updated at
    #   has deleted_at
    #   has polymorphic foreign keys
    #   has virtual columns
    #   virtual column filters (token, encrypted_password, etc)

    describe '#query' do
      context 'when model has associated ruby file' do
        it_behaves_like :log_structure, { ruby: true }
      end

      context 'when model is missing ruby file' do
        # potential m2m file
        it_behaves_like :log_structure, { ruby: false }
      end

      context 'when model has primary key' do
        it_behaves_like :log_structure, { pk: true }
      end

      context 'when model does not have primary key' do
        it_behaves_like :log_structure, { pk: false }
      end

      context 'when column count' do
        it_behaves_like :log_structure, { column_count: ->(count) { count == 2 } }
      end

      context 'when data column count' do
        it_behaves_like :log_structure, { data_column_count: ->(count) { count == 2 } }
      end

      context 'when foreign key column count' do
        it_behaves_like :log_structure, { foreign_key_column_count: ->(count) { count > 5 } }
        it_behaves_like :log_structure, { fk_column_count: ->(count) { count > 6 } }
        it_behaves_like :log_structure, { fk_count: ->(count) { count > 8 } }
      end

      context 'when polymorphic foreign key column count' do
        it_behaves_like :log_structure, { polymorphic_foreign_key_column_count: ->(count) { count == 1 } }
        it_behaves_like :log_structure, { poly_fk_column_count: ->(count) { count == 1 } }
        it_behaves_like :log_structure, { poly_fk_count: ->(count) { count == 1 } }
      end

      context 'when has standard timestamp columns' do
        it_behaves_like :log_structure, { timestamp: true }
      end

      context 'when has created_at' do
        it_behaves_like :log_structure, { created_at: true }
        it_behaves_like :log_structure, { created_at: false }
      end

      context 'when has updated_at' do
        it_behaves_like :log_structure, { updated_at: true }
        it_behaves_like :log_structure, { updated_at: false }
      end

      context 'when has deleted_at' do
        it_behaves_like :log_structure, { deleted_at: true }
        it_behaves_like :log_structure, { deleted_at: false }
      end
    end
  end

  def show_length(array)
    return '' if array.nil?

    length = array.length
    length.zero? ? '' : length
  end

  def show_bool(value)
    return '' unless value

    value
  end

  def show_exist(value)
    return '' if value.nil?

    true
  end
end
