# frozen_string_literal: true

class SmsTemplateCategory < ActiveRecord::Base
  enum category: {estimates: 1, orders: 2, sales: 3, campaigns: 5, contacts: 6, companies: 7, comments: 8}
  belongs_to :sms_template
end
