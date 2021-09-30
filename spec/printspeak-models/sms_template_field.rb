# frozen_string_literal: true

class SmsTemplateField < ActiveRecord::Base
  belongs_to :sms_template
  has_many :values, class_name: "SmsTemplateValue"

  def get_value(element, tenant_id = nil)
    result = values.where(element_type: element.class, element_id: element.id, tenant_id: nil).first.try(:value)
    if !tenant_id.nil?
      tenant_value = values.where(element_type: element.class, element_id: element.id, tenant_id: tenant_id).first.try(:value)
      result = tenant_value if !tenant_value.blank?
    end
    result
  end
end
