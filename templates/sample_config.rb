KDomain.configure do |config|
  config.default_main_key  = nil
  config.default_traits    = %i[
    trait1
    trait2
    trait3
  ]

  config.fallback_keys              = %i[
    name
    category
    description
    global
    key
    klass
    message
    lead_source
    body
    status
    subject
  ]

  config.register_entity(:action_log              , main_key: :action)
  config.register_entity(:backup                  , main_key: :filename)
  config.register_entity(:campaign_calendar_entry , main_key: :date)
  config.register_entity(:campaign_count          , main_key: :total_count)
  config.register_entity(:comment                 , main_key: :title)
  config.register_entity(:contact_group           , main_key: :email)
  config.register_entity(:email_alias             , main_key: :email)
  config.register_entity(:unsubscribe             , main_key: :email)
  config.register_entity(:email_credential        , main_key: :credentials)
  config.register_entity(:email_soft_bounce       , main_key: :email_address)
  config.register_entity(:suppressed_address      , main_key: :email_address)
  config.register_entity(:email_template_value    , main_key: :value)
  config.register_entity(:email_validation        , main_key: :address)
  config.register_entity(:enterprise_togglefield  , main_key: :field)
  config.register_entity(:event_stat              , main_key: :event_type)
  config.register_entity(:holiday_date            , main_key: :date)
  config.register_entity(:job_stat                , main_key: :job_name)
  config.register_entity(:original_user           , main_key: :target_user_id)
  config.register_entity(:pending_attachment      , main_key: :file_name)
  config.register_entity(:sales_base_tax          , main_key: :total)
  config.register_entity(:shared_user             , main_key: :shared_id)
  config.register_entity(:task_repeat             , main_key: :repeat_type)
  config.register_entity(:user                    , main_key: :username)
  config.register_entity(:token                   , main_key: :gmail_history_id)
end