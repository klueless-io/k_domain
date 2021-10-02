# # frozen_string_literal: true

# $VERBOSE = nil

# require_relative 'ruby_shims'

# path = "/Users/davidcruwys/dev/printspeak/printspeak-master/app/models/"
# files = %w[
#   account_history_data
#   activity
#   address
#   adjustment
#   api_log
#   asset
#   background_job
#   background_job_result
#   backup
#   bookmark
#   budget
#   budget_month
#   build
#   business_plan
#   business_plan_marketing_activity
#   business_plan_sales_investment
#   calendar
#   calendar_entry
#   calendar_entry_deletion
#   campaign
#   campaign_calendar_entry
#   campaign_count
#   campaign_exclusion
#   campaign_message
#   cash_sale
#   chart
#   clearbit_quota
#   comment
#   company
#   company_metric
#   contact
#   contact_group
#   contact_list
#   contact_list_count
#   contact_list_exclusion
#   contact_list_rule
#   country
#   country_state
#   date_helper
#   deployment
#   email
#   email_alias
#   email_attachment
#   email_credential
#   email_delivery
#   email_inbox
#   email_inbox_write
#   email_label
#   email_message
#   email_message_activity
#   email_soft_bounce
#   email_status
#   email_tag
#   email_template
#   email_template_category
#   email_template_field
#   email_template_value
#   email_validation
#   enterprise
#   enterprise_business_welcome
#   enterprise_salestarget
#   enterprise_togglefield
#   estimate
#   estimate_element
#   etl_setting
#   event
#   event_stat
#   exclusion
#   filter_default
#   finance_charge
#   financial_year
#   group
#   hidden_email_template
#   hidden_holiday
#   hidden_lead_type
#   hidden_task_type
#   holiday
#   holiday_date
#   holiday_state
#   identity
#   inquiry
#   inquiry_attachment
#   interest
#   interest_category
#   interest_context
#   invoice
#   invoice_element
#   job_stat
#   lead_source
#   lead_type
#   list
#   location
#   marketing_group
#   meeting
#   meeting_attendee
#   news
#   next_activity
#   note
#   order
#   original_user
#   pdf
#   pending_attachment
#   phone_call
#   portal_comment
#   production_location
#   proof
#   prospect_status
#   prospect_status_item
#   prospect_status_item_contact
#   prospect_status_version
#   region_config
#   report
#   report_row
#   sale
#   sales_base_tax
#   sales_category
#   sales_rep
#   sales_rep_update
#   sales_summary
#   sales_summary_pickup
#   sales_tag_by_month
#   salestarget
#   saved_report
#   shared_user
#   shipment
#   short_url
#   sms_template
#   sms_template_category
#   sms_template_field
#   statistic
#   tag
#   tag_category
#   tag_category_context
#   taken_by
#   taken_by_update
#   target
#   task
#   task_repeat
#   task_type
#   template_merger
#   tenant
#   token
#   tracker
#   tracker_hit
#   unsubscribe
#   user
#   wip
#   workflow
# ][1..10]# .select { |n| n == 'adjustment' } # .take(1)

# def load_retry(file, path, times)
#   return if times < 0

#   log.info(path)
#   load(path)
  
#   get_method_info(file)
# rescue => ex
#   # if ex.is_a?(NoMethodError)
#   #   log.exception(ex)
#   #   return
#   # end
#   if ex.is_a?(NameError)
#     log.kv('add module', ex.name)
#     eval("module #{ex.name}; end")
#     return load_retry(path, times-1)
#   end
#   log.exception(ex)
# end

# def get_method_info(file)
#   # puts file
#   klass = case file
#   when 'clearbit_quota'
#     ClearbitQuota
#   when 'account_history_data'
#     AccountHistoryData    
#   else
#     Module.const_get(file.classify)
#   end

#   class_info = Peeky.api.build_class_info(klass.new)

#   puts Peeky.api.render_class(:class_interface, class_info: class_info)

#   # puts class_info
# rescue => ex
#   log.exception(ex)
# end  

# files.each do |file|
#   # EVAL will not work (YET)
#   # here is a hint to making it work
#   # https://github.com/banister/method_source/issues/34
#   # ruby_file = File.read(file)
#   # puts ruby_file
#   # eval(ruby_file)

#   load_retry(file, File.join(path, "#{file}.rb"), 10)
# rescue => ex
#   log.exception(ex)
# end

# shim_writer

# RSpec.describe 'KDomain::RubyLoader::Load' do
# end
