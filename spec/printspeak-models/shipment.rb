class Shipment < ActiveRecord::Base
  include ApiLoggable
  include Excludable
  include Bookmarkable
  include Categorizable

  has_many :activities
  belongs_to :tenant
  belongs_to :company
  has_one :contact, class_name: "Contact", foreign_key: "id", primary_key: "contact_id"

  has_many :tasks, as: :taskable
  has_many :phone_calls, as: :phoneable
  has_many :emails, as: :context
  has_many :meetings, as: :context
  has_one :sales_rep_user, class_name: "User", foreign_key: "id", primary_key: "sales_rep_user_id"

  belongs_to :pdf

  default_scope { where(deleted: false) }
  scope :for_tenant, ->(tenant_id) { where(tenant_id: Array(tenant_id).first) }
  scope :for_dates,  ->(start_date, end_date) { where(shipment_date: start_date..end_date) }
  scope :needs_pdf, -> { where("shipment_date > '2015-07-01'").where(needs_pdf: true).where("pdf_error_count < 5").order("pdf_error_count ASC, shipment_date DESC, mbe_tracking ASC") }

  belongs_to :inquiry

  def name
    courier_tracking
  end

  def invoice_number
    courier_tracking
  end

  def report_name
    courier_tracking
  end

  def mbe_service
    tenant.enterprise.mbe_services.select { |mbe_service| mbe_service["id"].to_i == mbe_service_id.to_i }.first.try(:[], "name") || "Unknown"
  end

  def courier_name
    tenant.couriers.select { |courier| courier["id"].to_i == courier_id.to_i }.first.try(:[], "name") || "Unknown"
  end

  def courier_service
    tenant.courier_services(courier_id).select { |service| service["id"].to_i == courier_service_id.to_i }.first.try(:[], "name") || "Unknown"
  end

  def sales_rep
    SalesRep.where("platform_id = ? AND tenant_id = ?", sales_rep_platform_id, tenant_id).where(deleted: false).first
  end

  def notes
    Note.where(context_type: "Shipment", context_id: id)
  end

  def aggregated_notes
    notes
  end

  def aggregated_phone_calls
    phone_calls
  end

  def aggregated_tasks
    tasks
  end

  def aggregated_meetings
    meetings
  end

  def email_messages(search = nil, page = nil, per = nil)
    Email.get_contextual_email_messages(self, search, page, per)
  end

  def cogs_percentage
    result = 0
    if grand_total != 0 && !grand_total.nil? && total_cost != 0 && !total_cost.nil?
      result = (total_cost.to_f / grand_total.to_f) * 100
    end
    result
  end

  def invoice
    result = nil
    if !source_invoice_platform_id.blank?
      result = Invoice.where(tenant: tenant, platform_id: source_invoice_platform_id).first
    end
    result
  end

  def parent_invoice
    Invoice.where(tenant: tenant).where("platform_data->>'source_shipment_platform_id' = ?", platform_id).first
  end

  def apply_source_tag
    return if !associations_complete || source.blank?
    tag_category = TagCategory.where(enterprise_id: tenant.enterprise.id, system_match: source).first
    if tag_category
      tag_category.tag_context(self, manual: false)
    end
  end
end
