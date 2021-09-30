class Estimate < ActiveRecord::Base
  # has_paper_trail
  include ApiLoggable
  include Excludable
  include Bookmarkable
  include Categorizable

  TESTING_INVOICE_NUMBER = 2923
  TESTING_platform_id = 2928522

  default_scope { where(voided: false, deleted: false) }

  has_secure_token :public_token

  belongs_to :tenant, inverse_of: :estimates
  belongs_to :company, inverse_of: :estimates

  has_many :tasks, as: :taskable
  has_many :phone_calls, as: :phoneable
  has_many :comments, as: :commentable
  has_many :emails, as: :context
  has_many :activities
  has_many :notes, as: :context
  has_many :meetings, as: :context

  # has_one :production_location, :class_name => "ProductionLocation", :foreign_key => "id", :primary_key => "production_location_id"
  belongs_to :production_location, inverse_of: :invoices
  has_one :contact, class_name: "Contact", foreign_key: "id", primary_key: "contact_id"
  has_one :location, class_name: "Location", foreign_key: "id", primary_key: "location_user_id"
  has_one :taken_by_user, class_name: "User", foreign_key: "id", primary_key: "taken_by_user_id"

  belongs_to :contact_group
  belongs_to :pdf
  belongs_to :taken_by



  scope :for_tenant, ->(tenant_id) { where(tenant_id: Array(tenant_id).first) }
  scope :for_dates,  ->(start_date, end_date) { where(ordered_date: start_date..end_date) }
  scope :including_companies, -> { includes(:company) }

  belongs_to :inquiry

  def self.conversion_ratio
    conversion_ratio = 0

    if count > 0
      count_all = won.count + lost.count + pending.count
      conversion_ratio = ((won.count.to_f / count_all) * 100).round(2) if count_all > 0
    end

    conversion_ratio
  end

  scope :won,       -> { where(status: "Won") }
  scope :lost,      -> { where(status: "Lost") }
  scope :pending,   -> { where(status: "") }
  scope :overdue,   -> (today = Time.now) { where("wanted_by < ?", today) }
  scope :lonely, lambda { joins("LEFT OUTER JOIN tags ON estimates.id = tags.taggable_id").where("tags.taggable_id IS NULL") }
  scope :needs_pdf, -> { where("ordered_date > '2015-07-01'").where(needs_pdf: true).where("pdf_error_count < 5").order("pdf_error_count ASC, ordered_date DESC") }


  # scope :overdue, -> { where('wanted_by < ?', Time.now) }

  # def beginning_of_month
  #   ...
  # end

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

  def platform_id_for_psv
    Rails.env.production? ? self[:platform_id] : TESTING_platform_id
  end

  def invoice_number_for_psv
    Rails.env.production? ? self[:invoice_number] : TESTING_INVOICE_NUMBER
  end

  def is_archived?
    if on_pending_list.blank?
      true
    else
      false
    end
  end

  def archived_user
    User.where(id: archived_user_id).first
  end

  def won?
    true unless status != "Won"
  end

  class << self
    def group_year_month_day
      group("extract(year from created_at), extract(month from created_at), extract(day from created_at)")
    end

    def sales_estimates_for_tenant(tenant_id)
      where(tenant_id: tenant_id).
        group_year_month_day.
        select("extract(year from created_at) as year, extract(month from created_at) as month, extract(day from created_at) as day").
        select("sum(grand_total), avg(grand_total), count(grand_total)").
        order("year, month, day")
    end

    def conversion_ratio_by_company_id
      all.group(:company_id).
        select(:company_id).
        select("CASE
    WHEN count(CASE WHEN status IN ('Won', 'Lost', '') THEN 1 END) = 0 THEN 0
    ELSE (cast(count(CASE WHEN status = 'Won' THEN 1 END) as float) / cast(count(CASE WHEN status IN ('Won', 'Lost', '') THEN 1 END) as float))
  END AS conversion_ratio")
    end
  end

  def reason_text
    unit = Utils::Currency.symbole_of(self)
    case reason
    when "too_expensive"
      "Too Expensive#{ reason_value ? ' by: '+unit+reason_value : ''}"
    when "competitor_beter"
      "Competitor #{ reason_value ? reason_value : ''} Better"
    when "quote_too_late"
      "Quote too late"
    when "went_with_current_supplier"
      "Went with current supplier"
    when "could_not_meet_customer_requirement"
      "Could not meet the customer requirement#{ reason_value ? ': "'+reason_value+'"' : ''}"
    when "custom"
      "#{ reason_value ? reason_value : 'No reason specified'}"
    when "job_didnt_go_ahead"
      "Job didn't go ahead"
    when "multi_part_job"
      "Multi Part Job"
    when "received_better_value"
      "Received a better value quote"
    when "template"
      "Template"
    when "web_template"
      "Web Template"
    else
      reason.split("_").join(" ").camelcase.gsub("didnt",  "didn't")
    end
  end

  def sales_rep
    SalesRep.where("platform_id = ? AND tenant_id = ?", sales_rep_platform_id, tenant_id).where(deleted: false).first
  end

  def aggregated_tasks
    where_condition = "(tasks.taskable_type = 'Estimate' AND tasks.taskable_id = #{ActiveRecord::Base::sanitize(id)})"
    if inquiry
      where_condition << " OR (tasks.taskable_type = 'Inquiry' AND tasks.taskable_id = #{ActiveRecord::Base::sanitize(inquiry.id)})"
    end
    Task.where(tenant: tenant).
         where(where_condition).
         order(created_at: :asc)
  end

  def aggregated_phone_calls
    where_condition = "(phone_calls.phoneable_type = 'Estimate' AND phone_calls.phoneable_id = #{ActiveRecord::Base::sanitize(id)})"
    if inquiry
      where_condition << " OR (phone_calls.phoneable_type = 'Inquiry' AND phone_calls.phoneable_id = #{ActiveRecord::Base::sanitize(inquiry.id)})"
    end
    PhoneCall.where(tenant: tenant).
              where(where_condition).
              order(created_at: :desc)
  end

  def aggregated_notes
    where_condition = "(notes.context_type = 'Estimate' AND notes.context_id = #{ActiveRecord::Base::sanitize(id)})"
    if inquiry
      where_condition << " OR (notes.context_type = 'Inquiry' AND notes.context_id = #{ActiveRecord::Base::sanitize(inquiry.id)})"
    end
    Note.where(tenant: tenant).
         where(where_condition).
         order("created_at DESC, id DESC")
  end

  def aggregated_meetings
    where_condition = "(meetings.context_type = 'Estimate' AND meetings.context_id = #{ActiveRecord::Base::sanitize(id)})"
    if inquiry
      where_condition << " OR (meetings.context_type = 'Inquiry' AND meetings.context_id = #{ActiveRecord::Base::sanitize(inquiry.id)})"
    end
    Meeting.where(tenant: tenant).
            where(where_condition).
            order(created_at: :desc)
  end

  def self.to_csv
    CSV.generate(col_sep: all.first.tenant.enterprise.csv_col_sep) do |csv|
      desired_columns = ["Off Pending Date", "Estimate", "Name", "Total", "Company Name", "Status", "Converted Value", "Reason"]
      csv << desired_columns
      all.each do |result|
        csv << [
          result.send("get_off_pending"),
          "##{result.invoice_number}",
          "#{result.name}",
          "#{result.grand_total}",
          result.send("get_company_name"),
          "#{result.status}",
          result.send("order_value"),
          result.send("reason_info")
        ]
      end
    end
  end

  def get_off_pending
    tenant.local_strftime(off_pending_date, "%%DM-%%DM-%Y") if off_pending_date.present?
  end

  def get_company_name
    "#{company.name}" if company.present?
  end

  def reason_info
    "#{reason_text}" if reason.present?
  end

  def order_value
    if converted_invoice_number.present?
      invoice_total = tenant.orders.where(invoice_number: converted_invoice_number).first
      if invoice_total
        Utils::Currency.symbole_of(self)+invoice_total.grand_total.to_s
      else
        "-"
      end
    end
  end

  def portal_url
    return Rails.application.routes.url_helpers.url_for(controller: "/portal/estimate", action: :view, key: "invalid") if !id

    if portal_key.blank?
      self.portal_key = "#{id}#{SecureRandom.urlsafe_base64(64)}"
      save
    end
    Rails.application.routes.url_helpers.url_for(controller: "/portal/estimate", action: :view, key: portal_key)
  end
end
