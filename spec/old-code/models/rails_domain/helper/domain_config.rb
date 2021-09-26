class DomainConfig
  class << self
    def lookup(entity_name)
      @lookup ||= Hash.new do |h, key|
        h[key] = begin
          data = {
            main_key: nil,
            traits: %i[trait1 trait2 trait3]
          }

          lookup = configuration[key.to_sym] || {}

          OpenStruct.new(data.merge(lookup))
        end
      end
      @lookup[entity_name]
    end
    
    def configuration
      @configuration ||= {
        action_log: {
          main_key: :action
        },
        backup: {
          main_key: :filename
        },
        campaign_calendar_entry: {
          main_key: :date
        },
        campaign_count: {
          main_key: :total_count
        },
        comment: {
          main_key: :title
        },
        contact_group: {
          main_key: :email
        },
        email_alias: {
          main_key: :email
        },
        unsubscribe: {
          main_key: :email
        },
        email_credential: {
          main_key: :credentials
        },
        email_soft_bounce: {
          main_key: :email_address
        },
        suppressed_address: {
          main_key: :email_address
        },
        email_template_value: {
          main_key: :value
        },
        email_validation: {
          main_key: :address
        },
        enterprise_togglefield: {
          main_key: :field
        },
        event_stat: {
          main_key: :event_type
        },
        holiday_date: {
          main_key: :date
        },
        job_stat: {
          main_key: :job_name
        },
        original_user: {
          main_key: :target_user_id
        },
        pending_attachment: {
          main_key: :file_name
        },
        sales_base_tax: {
          main_key: :total
        },
        shared_user: {
          main_key: :shared_id
        },
        task_repeat: {
          main_key: :repeat_type
        },
        user: {
          main_key: :username
        },
        token: {
          main_key: :gmail_history_id
        }
      }
    end

  end
end
