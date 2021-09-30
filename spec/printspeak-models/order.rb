# frozen_string_literal: true

class Order < Invoice
  include ApiLoggable
  include Excludable
  include Bookmarkable
  include Categorizable

  self.table_name = "invoices"
  # belongs_to :sales_rep, :foreign_key => "user_id", :primary_key => "sales_rep_user_id"
  belongs_to :sale
  has_many :sales_reps, class_name: "SalesRep", foreign_key: "platform_id", primary_key: "sales_rep_platform_id"
  # has_many :activities

  scope :for_tenant, ->(tenant_id) { where(tenant_id: Array(tenant_id).first) }
  scope :for_dates,  ->(start_date, end_date) { where(ordered_date: start_date..end_date) }
  scope :including_companies, -> { includes(:company) }

  def email_messages(search = nil, page = nil, per = nil)
    Email.get_contextual_email_messages(self, search, page, per)
  end

  def phone_calls
    PhoneCall.where(tenant_id: tenant_id).where(phoneable_type: "Order", phoneable_id: id)
  end

  def tasks
    Task.where(tenant_id: tenant_id).where(taskable_type: "Order", taskable_id: id)
  end
end
