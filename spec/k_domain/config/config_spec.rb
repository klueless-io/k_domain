# frozen_string_literal: true

RSpec.describe KDomain::Config do
  let(:host_class) do
    Class.new { include KDomain::Config }
  end

  let(:instance) { host_class.new }

  context '.configuration' do
    subject { instance.configuration }

    it { is_expected.to be_a(KDomain::Config::Configuration) }

    describe '#configure' do
      before do
        instance.configure do |c|
          c.default_main_key = :xmen
          c.default_traits = %i[t1 t2]
          c.fallback_keys = %i[k1 k2]
          c.model(:good, main_key: :ymen, traits: %i[t1 t2 t3 t4])
        end
      end

      it do
        is_expected.to have_attributes(
          default_main_key: :xmen,
          default_traits: %i[t1 t2],
          fallback_keys: %i[k1 k2],
          models: include(KDomain::Config::Configuration::ConfigModel.new(:good, :ymen, %i[t1 t2 t3 t4]))
        )
      end

      context '#find_model' do
        subject { instance.configuration.find_model(table_name) }

        context 'when entity exists' do
          let(:table_name) { :good }
          it { is_expected.to have_attributes(name: :good, main_key: :ymen, traits: %i[t1 t2 t3 t4]) }
        end

        context 'when entity does not exist' do
          let(:table_name) { :bad }
          it { is_expected.to have_attributes(name: :bad, main_key: :xmen, traits: %i[t1 t2]) }
        end
      end
    end
  end

  describe 'KDomain.configuration' do
    subject { KDomain.configuration }

    it { is_expected.to be_a(KDomain::Config::Configuration) }
  end

  describe '#debug' do
    before do
      KDomain.configure do |config|
        config.default_main_key  = nil
        config.default_traits    = %i[
          trait1
          trait2
        ]

        config.fallback_keys = %i[
          name
          category
          description
        ]

        config.model(:action_log              , main_key: :action)
        config.model(:backup                  , main_key: :filename)
        config.model(:campaign_calendar_entry , main_key: :date)
      end
    end

    # it { KDomain.configuration.debug }

    context '.default_traits' do
      subject { KDomain.configuration.default_traits }

      it { is_expected.to eq(%i[trait1 trait2]) }

      context 'after reset' do
        describe '#reset' do
          before { KDomain.reset }

          it { is_expected.to eq(%i[trait1 trait2 trait3]) }

          # it { KDomain.configuration.debug }
        end
      end
    end
  end
end
