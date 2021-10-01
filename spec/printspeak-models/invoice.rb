class Invoice < ActiveRecord::Base
  include ApiLoggable
  include Categorizable

  default_scope { where("invoices.voided = false or invoices.voided is null").where(deleted: false) }
  # default_scope { where(ready: true) }
  # Invoice.all          # => SELECT * FROM invoices WHERE ready = true
  # Invoice.unscoped.all # => SELECT * FROM invoices
  # consider any raw SQL
  after_commit :recalc_statistics

  has_secure_token :public_token

  has_many :activities
  belongs_to :tenant, inverse_of: :invoices
  belongs_to :company, inverse_of: :invoices
  belongs_to :production_location, inverse_of: :invoices
  belongs_to :company, inverse_of: :sales

  has_one :location, class_name: "Location", foreign_key: "id", primary_key: "location_user_id"
  has_one :sales_rep_user, class_name: "User", foreign_key: "id", primary_key: "sales_rep_user_id"
  has_one :taken_by_user, class_name: "User", foreign_key: "id", primary_key: "taken_by_user_id"
  has_one :contact, class_name: "Contact", foreign_key: "id", primary_key: "contact_id"
  has_one :adjustment
  has_many :actions, as: :actionable
  has_many :tasks, as: :taskable
  has_many :phone_calls, as: :phoneable


  has_many :emails, as: :context
  has_many :meetings, as: :context
  has_many :proofs

  belongs_to :pdf



  # def self.to_csv(options = {})
  #   CSV.generate(options) do |csv|
  #     csv << column_names
  #     all.each do |invoice|
  #       csv << invoice.attributes.values_at(*column_names)
  #     end
  #   end
  # end

  scope :for_tenant, ->(tenant_id) { where(tenant_id: Array(tenant_id).first) }
  scope :for_dates,  ->(start_date, end_date) { where(ordered_date: start_date..end_date) }
  scope :including_companies, -> { includes(:company) }
  scope :lonely, lambda { joins("LEFT OUTER JOIN tags ON invoices.id = tags.taggable_id").where("tags.taggable_id IS NULL") }
  scope :needs_pdf, -> { where("ordered_date > '2015-07-01'").where(needs_pdf: true).where("pdf_error_count < 5").order("pdf_error_count ASC, ordered_date DESC") }
  scope :invoiced, -> (invoiced_only=true) { where(Invoice.INVOICED) if invoiced_only }
  scope :deferred, -> (deferred_only=true) { where(Invoice.DEFERRED) if deferred_only }

  #TODO Deprecate these in favor of the above, leaving them in as there are other PRs still using them
  scope :mbe_invoiced, -> (invoiced_only=true) { invoiced(invoiced_only) }
  scope :mbe_deferred, -> (deferred_only=true) { deferred(deferred_only) }

  def self.INVOICED
    "COALESCE(invoices.platform_data->>'invoiced', 'false')::BOOLEAN = TRUE"
  end

  def self.DEFERRED
    "COALESCE(invoices.platform_data->>'deferred', 'false')::BOOLEAN = TRUE"
  end

  def update_invoiced
    invoiced = false
    if tenant.enterprise.invoiced_types.include?(invoice_type)
      invoiced = true
    end

    if invoiced != platform_data["invoiced"]
      platform_data["invoiced"] = invoiced
      save
    end
  end

  def update_deferred
    deferred = false
    if tenant.enterprise.deferred_types.include?(invoice_type) && platform_data["source_invoice_platform_id"].blank?
      if invoice_type == tenant.enterprise.invoice_types.key("Shipment")
        deferred = true if shipment && !shipment.not_to_invoice && shipment.source_invoice_platform_id.blank?
      else
        deferred = true
      end
    end

    if deferred != platform_data["deferred"]
      platform_data["deferred"] = deferred
      save
    end
  end

  def shipment
    result = nil
    if !platform_data["source_shipment_platform_id"].blank?
      result = Shipment.where(tenant: tenant, platform_id: platform_data["source_shipment_platform_id"]).first
    end
    result
  end

  def parent_invoice
    Invoice.where(tenant: tenant).where("platform_data->>'source_invoice_platform_id' = ?", platform_id).first
  end

  def cogs_percentage
    grand_total_inc_non_sales_minus_tax = grand_total_inc_tax.to_f - tax.to_f

    if grand_total_inc_non_sales_minus_tax.to_f != 0.0 &&
      total_cost.to_f != 0.0 &&
      !grand_total_inc_non_sales_minus_tax.nil? &&
      !total_cost.nil?
     total_cost / (grand_total_inc_tax.to_f - tax.to_f) * 100
    else
      0
    end
  end

  def sales_rep
    SalesRep.where("platform_id = ? AND tenant_id = ?", sales_rep_platform_id, tenant_id).where(deleted: false).first
  end

  def notes
    Note.where(context_type: [Invoice, Order, Sale], context_id: id)
  end

  def source_estimate
    result = nil
    if !source_estimate_number.blank?
      if converted || source_invoice_number.blank?
        result = Estimate.where(tenant: tenant, invoice_number: source_estimate_number).first
      end
    end
    result
  end

  def inquiry
    Inquiry.where(id: inquiry_id).first
  end

  def aggregated_tasks
    where_condition = "(tasks.taskable_type IN ('Invoice', 'Sale', 'Order') AND tasks.taskable_id = #{ActiveRecord::Base::sanitize(id)})"
    if source_estimate
      where_condition << " OR (tasks.taskable_type = 'Estimate' AND tasks.taskable_id = #{ActiveRecord::Base::sanitize(source_estimate.id)})"
      if source_estimate.inquiry
        where_condition << " OR (tasks.taskable_type = 'Inquiry' AND tasks.taskable_id = #{ActiveRecord::Base::sanitize(source_estimate.inquiry.id)})"
      end
    end
    if inquiry
      where_condition << " OR (tasks.taskable_type = 'Inquiry' AND tasks.taskable_id = #{ActiveRecord::Base::sanitize(inquiry.id)})"
    end
    Task.where(tenant: tenant).
         where(where_condition).
         order(created_at: :asc)
  end

  def aggregated_phone_calls
    where_condition = "(phone_calls.phoneable_type IN ('Invoice', 'Sale', 'Order') AND phone_calls.phoneable_id = #{ActiveRecord::Base::sanitize(id)})"
    if source_estimate
      where_condition << " OR (phone_calls.phoneable_type = 'Estimate' AND phone_calls.phoneable_id = #{ActiveRecord::Base::sanitize(source_estimate.id)})"
      if source_estimate.inquiry
        where_condition << " OR (phone_calls.phoneable_type = 'Inquiry' AND phone_calls.phoneable_id = #{ActiveRecord::Base::sanitize(source_estimate.inquiry.id)})"
      end
    end
    if inquiry
      where_condition << " OR (phone_calls.phoneable_type = 'Inquiry' AND phone_calls.phoneable_id = #{ActiveRecord::Base::sanitize(inquiry.id)})"
    end
    PhoneCall.where(tenant: tenant).
              where(where_condition).
              order(created_at: :desc)
  end

  def aggregated_notes
    where_condition = "(notes.context_type IN ('Invoice', 'Sale', 'Order') AND notes.context_id = #{ActiveRecord::Base::sanitize(id)})"
    if source_estimate
      where_condition << " OR (notes.context_type = 'Estimate' AND notes.context_id = #{ActiveRecord::Base::sanitize(source_estimate.id)})"
      if source_estimate.inquiry
        where_condition << " OR (notes.context_type = 'Inquiry' AND notes.context_id = #{ActiveRecord::Base::sanitize(source_estimate.inquiry.id)})"
      end
    end
    if inquiry
      where_condition << " OR (notes.context_type = 'Inquiry' AND notes.context_id = #{ActiveRecord::Base::sanitize(inquiry.id)})"
    end
    Note.where(tenant: tenant).
         where(where_condition).
         order("created_at DESC, id DESC")
  end

  def aggregated_meetings
    where_condition = "(meetings.context_type IN ('Invoice', 'Sale', 'Order') AND meetings.context_id = #{ActiveRecord::Base::sanitize(id)})"
    if source_estimate
      where_condition << " OR (meetings.context_type = 'Estimate' AND meetings.context_id = #{ActiveRecord::Base::sanitize(source_estimate.id)})"
      if source_estimate.inquiry
        where_condition << " OR (meetings.context_type = 'Inquiry' AND meetings.context_id = #{ActiveRecord::Base::sanitize(source_estimate.inquiry.id)})"
      end
    end
    if inquiry
      where_condition << " OR (meetings.context_type = 'Inquiry' AND meetings.context_id = #{ActiveRecord::Base::sanitize(inquiry.id)})"
    end
    Meeting.where(tenant: tenant).
            where(where_condition).
            order(created_at: :desc)
  end

  def pay_url(target_tenant: tenant, amount: nil, number: nil, name: nil, email: nil)
    result = ""

    if !target_tenant.try(:pay_url).blank?
      result = target_tenant.pay_url
      result = result.gsub("{{amount}}", URI::encode("%.02f" % (amount || try(:amount_due) || 0)))
      result = result.gsub("{{number}}", URI::encode(number || try(:invoice_number).try(:to_s) || ""))
      result = result.gsub("{{name}}", URI::encode(name || try(:company).try(:name) || try(:contact).try(:full_name) || ""))
      result = result.gsub("{{email}}", URI::encode(email || try(:contact).try(:email) || ""))
    end

    result
  end

  def portal_url
    return Rails.application.routes.url_helpers.url_for(controller: "/portal/proof", action: :view, key: "invalid") if !id

    if portal_key.blank?
      self.portal_key = "#{id}#{SecureRandom.urlsafe_base64(64)}"
      save
    end
    Rails.application.routes.url_helpers.url_for(controller: "/portal/proof", action: :view, key: portal_key)
  end

  def proof
    if proof_approved_id
      result = Proof.where(id: proof_approved_id).first
    end
    if result.nil?
      result = Proof.where(id: proof_id).first
    end
    if result.nil?
      result = latest_proof
    end
    result
  end

  def proofs
    Proof.where(tenant_id: tenant_id, invoice_id: id, revision_of_id: nil).order(number: :asc)
  end

  def latest_proof
    Proof.where(invoice_id: id).order(created_at: :desc).first
  end

  def proof_count
    Proof.where(invoice_id: id, revision_of_id: nil).count
  end

  def self.bulk_all_tags(target_tenant, target_ids, category_ids, manual = false)
    Tag.unscoped.where(tenant_id: target_tenant.id, taggable: self, tag_category_id: category_ids)
  end

  private

  def recalc_statistics
    if (previous_changes.keys & %w[company_id pickup_date deleted voided]).any?
      Platform::Tagger::SingleSaleOnly.new(company).perform if company
      Platform::Tagger::FirstSale.new(company).perform if company
    end

    if (previous_changes.keys & %w[contact_id pickup_date deleted voided]).any?
      Platform::Tagger::SingleSaleOnlyContact.new(contact).perform if contact
      Platform::Tagger::FirstSaleContact.new(contact).perform if contact
    end
  end
end
