class Contact < ActiveRecord::Base
  enum potential: {cold: 1, warm: 2, hot: 3}

  include PgSearch
  include EstimateConvertable
  include ApiLoggable
  include Excludable
  include Bookmarkable
  include Categorizable

  belongs_to :tenant
  belongs_to :company
  belongs_to :prospect_status
  belongs_to :parent_contact, class_name: "Contact", foreign_key: "parent_contact_id"
  has_many :invoices
  has_many :sales
  has_many :estimates
  has_many :orders
  has_many :tasks, as: :taskable
  has_many :phone_calls, as: :phoneable
  has_many :activities
  has_many :campaign_messages
  has_many :emails, as: :context
  has_many :notes, as: :context
  has_one :location, class_name: "Location", foreign_key: "id", primary_key: "location_user_id"
  has_one :sales_rep_user, class_name: "User", foreign_key: "id", primary_key: "sales_rep_user_id"
  has_many :next_activities

  belongs_to :address
  has_and_belongs_to_many :contact_lists, -> { uniq }
  has_many :interest_contexts, as: :context
  has_one :inquiry
  has_many :inquiries
  belongs_to :lead_type

  before_save :check_email_changed
  has_many :prospect_status_item_contacts

  pg_search_scope :search_by_text, against: %i[first_name last_name], using: {tsearch: {prefix: true}}
  scope :marketing, -> (tenant) { joins("LEFT OUTER JOIN companies ON companies.id = contacts.company_id").where(tenant_id: tenant.id, deleted: false, temp: false, unsubscribed: false, companies: {marketing_do_not_mail: false}) }
  scope :no_pending_estimates, -> { where("NOT EXISTS(SELECT null FROM estimates WHERE estimates.contact_id = contacts.id AND estimates.on_pending_list = true)") }
  scope :no_pending_invoices, -> { where("NOT EXISTS(SELECT null FROM invoices WHERE invoices.contact_id = contacts.id AND invoices.on_pending_list = true)") }

  scope :rolling_1_month_sales, -> (invoiced_only=false) { select("(#{Sale.select('COALESCE(SUM(invoices.grand_total), 0)').invoiced(invoiced_only).where(pickup_date: (Date.tomorrow - 1.month)..Date.tomorrow).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as rolling_1_month_sales") }
  scope :calculated_rolling_1_month_sales, -> (invoiced_only=false) { select("(#{Sale.select('COALESCE(SUM(invoices.grand_total), 0) + COALESCE(SUM(adjustments.total), 0)').invoiced(invoiced_only).joins('LEFT OUTER JOIN "adjustments" ON adjustments.invoice_id = invoices.id AND adjustments.tenant_id = invoices.tenant_id AND adjustments.affect_sales = true AND adjustments.deleted = FALSE AND adjustments.voided = FALSE').where(pickup_date: (Date.tomorrow - 1.month)..Date.tomorrow).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as calculated_rolling_1_month_sales") }
  scope :calculated_rolling_12_month_sales, -> (invoiced_only=false) { select("(#{Sale.select('COALESCE(SUM(invoices.grand_total), 0) + COALESCE(SUM(adjustments.total), 0)').invoiced(invoiced_only).joins('LEFT OUTER JOIN "adjustments" ON adjustments.invoice_id = invoices.id AND adjustments.tenant_id = invoices.tenant_id AND adjustments.affect_sales = true AND adjustments.deleted = FALSE AND adjustments.voided = FALSE').where(pickup_date: (Date.tomorrow - 1.year)..Date.tomorrow).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as calculated_rolling_12_month_sales") }
  scope :calculated_rolling_12_month_sales_ly, -> (invoiced_only=false) { select("(#{Sale.select('COALESCE(SUM(invoices.grand_total), 0) + COALESCE(SUM(adjustments.total), 0)').invoiced(invoiced_only).joins('LEFT OUTER JOIN "adjustments" ON adjustments.invoice_id = invoices.id AND adjustments.tenant_id = invoices.tenant_id AND adjustments.affect_sales = true AND adjustments.deleted = FALSE AND adjustments.voided = FALSE').where(pickup_date: (Date.tomorrow - 2.years)..(Date.tomorrow - 1.year)).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as calculated_rolling_12_month_sales_ly") }
  scope :calculated_rolling_12_month_sales_ly_ly, -> (invoiced_only=false) { select("(#{Sale.select('COALESCE(SUM(invoices.grand_total), 0) + COALESCE(SUM(adjustments.total), 0)').invoiced(invoiced_only).joins('LEFT OUTER JOIN "adjustments" ON adjustments.invoice_id = invoices.id AND adjustments.tenant_id = invoices.tenant_id AND adjustments.affect_sales = true AND adjustments.deleted = FALSE AND adjustments.voided = FALSE').where(pickup_date: (Date.tomorrow - 3.years)..(Date.tomorrow - 2.years)).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as calculated_rolling_12_month_sales_ly_ly") }
  scope :calculated_rolling_12_month_cogs, -> (invoiced_only=false) { select("(#{Sale.select('ROUND(CASE COALESCE(SUM(invoices.grand_total_inc_tax), 0) WHEN 0 THEN 0 ELSE COALESCE(SUM(invoices.total_cost), 0) / SUM(invoices.grand_total_inc_tax) END, 2)').invoiced(invoiced_only).where(pickup_date: (Date.tomorrow - 1.year)..Date.tomorrow).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as calculated_rolling_12_month_cogs") }

  scope :calculated_financial_year_sales, -> (tenant, invoiced_only=false) { select("(#{Sale.select('COALESCE(SUM(invoices.grand_total), 0) + COALESCE(SUM(adjustments.total), 0)').invoiced(invoiced_only).joins('LEFT OUTER JOIN "adjustments" ON adjustments.invoice_id = invoices.id AND adjustments.tenant_id = invoices.tenant_id AND adjustments.affect_sales = true AND adjustments.deleted = FALSE AND adjustments.voided = FALSE').where(pickup_date: FinancialYear.new(tenant).start_date..FinancialYear.new(tenant).end_date).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as calculated_financial_year_sales") }
  scope :calculated_financial_year_sales_ly, -> (tenant, invoiced_only=false) { select("(#{Sale.select('COALESCE(SUM(invoices.grand_total), 0) + COALESCE(SUM(adjustments.total), 0)').invoiced(invoiced_only).joins('LEFT OUTER JOIN "adjustments" ON adjustments.invoice_id = invoices.id AND adjustments.tenant_id = invoices.tenant_id AND adjustments.affect_sales = true AND adjustments.deleted = FALSE AND adjustments.voided = FALSE').where(pickup_date: (FinancialYear.new(tenant).start_date - 1.year)..(FinancialYear.new(tenant).end_date - 1.year)).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as calculated_financial_year_sales_ly") }
  scope :calculated_financial_year_sales_ly_ly, -> (tenant, invoiced_only=false) { select("(#{Sale.select('COALESCE(SUM(invoices.grand_total), 0) + COALESCE(SUM(adjustments.total), 0)').invoiced(invoiced_only).joins('LEFT OUTER JOIN "adjustments" ON adjustments.invoice_id = invoices.id AND adjustments.tenant_id = invoices.tenant_id AND adjustments.affect_sales = true AND adjustments.deleted = FALSE AND adjustments.voided = FALSE').where(pickup_date: (FinancialYear.new(tenant).start_date - 2.years)..(FinancialYear.new(tenant).end_date - 2.years)).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as calculated_financial_year_sales_ly_ly") }
  scope :calculated_financial_year_cogs, -> (tenant, invoiced_only=false) { select("(#{Sale.select('ROUND(CASE COALESCE(SUM(invoices.grand_total_inc_tax), 0) WHEN 0 THEN 0 ELSE COALESCE(SUM(invoices.total_cost), 0) / SUM(invoices.grand_total_inc_tax) END, 2)').invoiced(invoiced_only).where(pickup_date: FinancialYear.new(tenant).start_date..FinancialYear.new(tenant).end_date).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as calculated_financial_year_cogs") }

  scope :calculated_average_invoice, -> (invoiced_only=false) { select("(#{Sale.select('COALESCE(ROUND(AVG(invoices.grand_total), 2), 0)').invoiced(invoiced_only).where(pickup_date: (Date.tomorrow - 1.year)..Date.tomorrow).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as calculated_average_invoice") }
  scope :calculated_oldest_rolling_1_invoice, -> (invoiced_only=false) { select("(#{Sale.select('invoices.pickup_date').invoiced(invoiced_only).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').where('invoices.pickup_date >= ?', (Date.tomorrow - 1.month)).order(pickup_date: :asc).limit(1).to_sql}) as calculated_oldest_rolling_1_invoice") }
  scope :calculated_oldest_rolling_12_invoice, -> (invoiced_only=false) { select("(#{Sale.select('invoices.pickup_date').invoiced(invoiced_only).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').where('invoices.pickup_date >= ?', (Date.tomorrow - 1.year)).order(pickup_date: :asc).limit(1).to_sql}) as calculated_oldest_rolling_12_invoice") }
  scope :calculated_oldest_rolling_12_ly_invoice, -> (invoiced_only=false) { select("(#{Sale.select('invoices.pickup_date').invoiced(invoiced_only).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').where('invoices.pickup_date >= ?', (Date.tomorrow - 2.years)).order(pickup_date: :asc).limit(1).to_sql}) as calculated_oldest_rolling_12_ly_invoice") }
  scope :calculated_oldest_rolling_12_ly_ly_invoice, -> (invoiced_only=false) { select("(#{Sale.select('invoices.pickup_date').invoiced(invoiced_only).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').where('invoices.pickup_date >= ?', (Date.tomorrow - 3.years)).order(pickup_date: :asc).limit(1).to_sql}) as calculated_oldest_rolling_12_ly_ly_invoice") }
  scope :calculated_first_sale_date, -> (invoiced_only=false) { select("(#{Sale.select('invoices.pickup_date').invoiced(invoiced_only).where('invoices.contact_id = contacts.id').order(pickup_date: :asc).limit(1).to_sql}) as calculated_first_sale_date") }
  scope :calculated_last_pickup_date, -> (invoiced_only=false) { select("(#{Sale.select('invoices.pickup_date').invoiced(invoiced_only).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').order(pickup_date: :desc).limit(1).to_sql}) as calculated_last_pickup_date") }

  scope :calculated_last_sale_order_date, -> (invoiced_only=false) { select("(#{Sale.select('invoices.ordered_date').where.not(ordered_date: nil).where('invoices.contact_id = contacts.id').invoiced(invoiced_only).order(ordered_date: :desc).limit(1).to_sql}) as calculated_last_sale_order_date") }
  scope :calculated_last_sale_pickup_date, -> (invoiced_only=false) { select("(#{Sale.select('invoices.pickup_date').where.not(pickup_date: nil).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').invoiced(invoiced_only).order(pickup_date: :desc).limit(1).to_sql}) as calculated_last_sale_pickup_date") }
  scope :calculated_last_shipment_date, -> { select("(#{Shipment.select('shipments.shipment_date').where.not(shipment_date: nil).where('shipments.tenant_id = contacts.tenant_id AND shipments.shipment_date IS NOT NULL AND shipments.contact_id = contacts.id').order(shipment_date: :desc).limit(1).to_sql}) as calculated_last_shipment_date") }

  scope :order_count, -> { select("(#{Order.select('COUNT(*)').where(on_pending_list: true).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as order_count") }
  scope :with_ranks, -> { select("contacts.*, rank() OVER (PARTITION BY contacts.tenant_id ORDER BY contacts.rolling_12_month_sales DESC NULLS LAST) AS calculated_rank") }
  scope :with_ranks_ly, -> { select("contacts.*, rank() OVER (PARTITION BY contacts.tenant_id ORDER BY contacts.rolling_12_month_sales_ly DESC NULLS LAST) AS calculated_rank_ly") }
  scope :with_ranks_ly_ly, -> { select("contacts.*, rank() OVER (PARTITION BY contacts.tenant_id ORDER BY contacts.rolling_12_month_sales_ly_ly DESC NULLS LAST) AS calculated_rank_ly_ly") }

  scope :with_ranks_financial_year, -> { select("contacts.*, rank() OVER (PARTITION BY contacts.tenant_id ORDER BY contacts.financial_year_sales DESC NULLS LAST) AS calculated_rank_financial_year") }
  scope :with_ranks_financial_year_ly, -> { select("contacts.*, rank() OVER (PARTITION BY contacts.tenant_id ORDER BY contacts.financial_year_sales_ly DESC NULLS LAST) AS calculated_rank_financial_year_ly") }
  scope :with_ranks_financial_year_ly_ly, -> { select("contacts.*, rank() OVER (PARTITION BY contacts.tenant_id ORDER BY contacts.financial_year_sales_ly_ly DESC NULLS LAST) AS calculated_rank_financial_year_ly_ly") }

  scope :calculated_last_email_sent, -> { select("(#{Activity.select(:source_created_at).where("activities.contact_id = contacts.id AND activities.activity_for = 'email' AND activities.email_id IS NOT NULL").order('activities.source_created_at DESC NULLS LAST').limit(1).to_sql}) AS calculated_last_email_sent") }
  scope :calculated_last_email_received, -> { select("(#{Activity.select(:source_created_at).where("activities.contact_id = contacts.id AND activities.activity_for = 'email' AND activities.email_id IS NULL").order('activities.source_created_at DESC NULLS LAST').limit(1).to_sql}) AS calculated_last_email_received") }
  scope :calculated_last_phone_call, -> { select("(#{Activity.select(:source_created_at).where("activities.contact_id = contacts.id AND activities.activity_for = 'phone_call' AND activities.phone_call_id IS NOT NULL").order('activities.source_created_at DESC NULLS LAST').limit(1).to_sql}) AS calculated_last_phone_call") }
  scope :calculated_last_order_date, -> { select("(#{Order.select('invoices.ordered_date').where.not(ordered_date: nil).where('invoices.contact_id = contacts.id').order(ordered_date: :desc).limit(1).to_sql}) as calculated_last_order_date") }
  scope :calculated_order_count, -> { select("(#{Order.select('COUNT(*)').where(on_pending_list: true).where('invoices.ordered_date IS NOT NULL AND invoices.contact_id = contacts.id').to_sql}) as calculated_order_count") }

  scope :by_parents, ->  { where("contacts.parent_contact_id = contacts.id") }
  scope :by_parents_with_unmapped, -> { where("contacts.parent_contact_id = contacts.id OR parent_contact_id = ?", -1) }

  scope :single_purchase, -> { where.not(single_sale_only_at: nil) }
  scope :first_sale, -> { where.not(first_sale_at: nil) }

  attr_accessor :score

  # validate :name_must_be_unique
  # validates :first_name, presence: { message: 'First Name is required.' }, on: :create
  # validates :last_name, presence: { message: 'Last Name is required.' }, on: :create
  # validates :email, presence: { message: 'Email is required.' }

  # phony_normalize :phone, default_country_code: 'AU'
  # validates :phone, :phony_plausible => true
  # validates :email, format: /\A[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,6}\z/i
  def sales_rep
    SalesRep.where("platform_id = ? AND tenant_id = ?", sales_rep_platform_id, tenant_id).where(deleted: false).first
  end

  def name_must_be_unique
    first_name_string = try(:first_name) || ""
    last_name_string = try(:last_name) || ""
    string = (first_name_string + " " + last_name_string)

    contact = company.contacts.where("trim(regexp_replace(COALESCE(contacts.first_name, '') || ' ' || COALESCE(contacts.last_name, ''), '\s+', ' ', 'g')) ILIKE (?)", string).first if company.present? and string.present?

    if contact.present?
      errors.add(:name, "This contact exists. Please choose a different name.")
    end
  end

  def check_email_changed
    if email_changed?
      self.needs_email_validation = true
      self.email_validation_attempts = -1
    end
  end

  def sales_lly
    sales.where(ordered_date: "2014-07-01".."2015-06-30").sum(:grand_total)
  end

  def sales_ly
    sales.where(ordered_date: "2015-07-01".."2016-06-30").sum(:grand_total)
  end

  def sales_ty
    sales.where(ordered_date: "2016-07-01".."2016-07-30").sum(:grand_total)
  end

  def yoy_growth
    percentage = 0

    if sales_lly > 0
      percentage = (sales_ly/sales_lly) * 100
    end


    if percentage < 100 && percentage != 0
      percentage = (percentage - 100)
    end

    percentage
  end

  def fy_count(start_date = (Time.zone.now - 1.years) , end_date = (Time.zone.now))
    count = estimates.where(ordered_date: start_date..end_date).count
    # estimates.where("status = ''").count if count == 0 || 0
  end

  def get_avg_estimate_conversion_fy
    end_date = Date.today
    start_date = end_date - 1.year

    if won_estimates(start_date, end_date) > 0
      ((won_estimates(start_date, end_date).to_f / (won_estimates(start_date, end_date) + lost_estimates(start_date, end_date) + pending_estimates(start_date, end_date))) * 100).round(2) || 0
    else
      0
    end
  end

  def month_sales
    start_date  = Date.today.beginning_of_month
    end_date    = Date.today.end_of_month

    sales.where(ordered_date: start_date..end_date).sum(:grand_total)
  end

  def full_name
    if Platform.is_mbe?(tenant) && first_name.blank? && last_name.blank?
      "Account Contact"
    else
      "#{first_name} #{last_name}".squish
    end
  end

  def rolling_12_month_rank
    result = nil
    if !rolling_12_month_sales.nil? && rolling_12_month_sales > 0
      if self["calculated_rank"]
        result = self["calculated_rank"]
      else
        result = Contact.where(tenant_id: tenant.id).where("rolling_12_month_sales > ?", rolling_12_month_sales).order("rolling_12_month_sales DESC NULLS LAST").count + 1
      end
    end
    result
  end

  def rolling_12_month_rank_ly
    result = nil
    if !rolling_12_month_sales_ly.nil? && rolling_12_month_sales_ly > 0
      if self["calculated_rank_ly"]
        result = self["calculated_rank_ly"]
      else
        result = Contact.where(tenant_id: tenant.id).where("rolling_12_month_sales_ly > ?", rolling_12_month_sales_ly).order("rolling_12_month_sales_ly DESC NULLS LAST").count + 1
      end
    end
    result
  end

  def rolling_12_month_rank_ly_ly
    result = nil
    if !rolling_12_month_sales_ly_ly.nil? && rolling_12_month_sales_ly_ly > 0
      if self["calculated_rank_ly_ly"]
        result = self["calculated_rank_ly_ly"]
      else
        result = Contact.where(tenant_id: tenant.id).where("rolling_12_month_sales_ly_ly > ?", rolling_12_month_sales_ly_ly).order("rolling_12_month_sales_ly_ly DESC NULLS LAST").count + 1
      end
    end
    result
  end

  def financial_year_rank
    result = nil
    if !financial_year_sales.nil? && financial_year_sales > 0
      if self["calculated_rank"]
        result = self["calculated_rank"]
      else
        result = Contact.where(tenant_id: tenant.id).where("financial_year_sales > ?", financial_year_sales).order("financial_year_sales DESC NULLS LAST").count + 1
      end
    end
    result
  end

  def financial_year_rank_ly
    result = nil
    if !financial_year_sales_ly.nil? && financial_year_sales_ly > 0
      if self["calculated_rank_ly"]
        result = self["calculated_rank_ly"]
      else
        result = Contact.where(tenant_id: tenant.id).where("financial_year_sales_ly > ?", financial_year_sales_ly).order("financial_year_sales_ly DESC NULLS LAST").count + 1
      end
    end
    result
  end

  def financial_year_rank_ly_ly
    result = nil
    if !financial_year_sales_ly_ly.nil? && financial_year_sales_ly_ly > 0
      if self["calculated_rank_ly_ly"]
        result = self["calculated_rank_ly_ly"]
      else
        result = Contact.where(tenant_id: tenant.id).where("financial_year_sales_ly_ly > ?", financial_year_sales_ly_ly).order("financial_year_sales_ly_ly DESC NULLS LAST").count + 1
      end
    end
    result
  end

  alias name full_name

  def prospect?
    Company.unscoped.where(tenant_id: tenant_id, id: company_id).first.try(:prospect) if company_id.present? && temp == false
  end

  def campaigns
    Campaign.joins(:messages).joins("JOIN contacts ON contacts.id = campaign_messages.contact_id").where(tenant_id: tenant_id, campaign_messages: {contact_id: id}).where.not(parent_id: nil).group("campaigns.id")
  end

  def info(*args)
    result = nil

    custom = custom_data
    clearbit = clearbit_data
    args.each do |arg|
      custom = custom.try(:[], arg)
      clearbit = clearbit.try(:[], arg)
    end
    result = custom unless custom.nil?
    result = clearbit if custom.nil? && !clearbit.nil?

    result
  end

  def parent
    result = nil
    if parent_contact_id == id
      result = self
    elsif parent_contact_id > 0
      result = Contact.where(id: parent_contact_id).first
    end
    result
  end

  def potential_matches(page = 1, per = 10)
    local_email = Email.clean_email(email)
    local_first_name = first_name.try(:strip).try(:downcase)
    local_last_name = last_name.try(:strip).try(:downcase)

    conditions = local_email.blank? ? "" : "(LOWER(TRIM(email)) = #{ActiveRecord::Base::sanitize(local_email)})"

    if !local_first_name.blank?
      conditions << " OR" unless conditions.blank?
      conditions << "(LOWER(TRIM(first_name)) = #{ActiveRecord::Base::sanitize(local_first_name)})"
    end

    if !local_last_name.blank?
      conditions << " OR" unless conditions.blank?
      conditions << "(LOWER(TRIM(last_name)) = #{ActiveRecord::Base::sanitize(local_last_name)})"
    end

    self.score = 200
    matched_contacts = [self]

    if !conditions.blank?
      potential_matches = Contact.where(tenant_id: tenant_id).where(conditions).where.not(id: id, company_id: nil)
      potential_matches.each do |potential_match|
        score = Contact.compare_contacts(self, potential_match)
        if score > 0
          potential_match.score = score
          matched_contacts << potential_match
        end
      end
    end

    matched_contacts.sort! do |a, b|
      result = -1 if a.temp == true
      result = 1 if b.temp == true
      result = 0 if a.temp == b.temp
      result.nil? || result == 0 ? (a.score <=> b.score) : result
    end
    matched_contacts.reverse!

    if page.to_i > 0
      Kaminari.paginate_array(matched_contacts).page(page).per(per)
    else
      Kaminari.paginate_array(matched_contacts).page(1).per(matched_contacts.count)
    end
  end

  def self.compare_contacts(a, b)
    result = 0
    return 0 if a.company_id.nil? || b.company_id.nil? || a.company_id != b.company_id

    weights = {
      first_name: 40,
      last_name: 40,
      email: 10,
      phone: 10,
      mobile: 10
    }

    weights.each do |key, value|
      next if a[key].blank? || b[key].blank?
      a_value = a[key]
      b_value = b[key]

      a_value = a_value.to_s.downcase.strip
      b_value = b_value.to_s.downcase.strip

      if a_value == b_value
        result += value
      else
        result -= value
      end
    end

    result
  end

  def location
    result = Location.where(id: location_user_id).first if !location_user_id.nil?
    result = Location.where(id: company.location_user_id).first if result.nil? && !company.nil? && !company.location_user_id.nil?
    result
  end

  def aggregated_tasks
    Task.joins("LEFT OUTER JOIN estimates ON estimates.id = tasks.taskable_id").
         joins("LEFT OUTER JOIN invoices ON invoices.id = tasks.taskable_id").
         joins("LEFT OUTER JOIN inquiries ON inquiries.id = tasks.taskable_id").
         where(tenant: tenant).
         where(%Q{
          (
            (tasks.taskable_type = 'Inquiry' AND inquiries.contact_id = #{id})
            OR (tasks.taskable_type = 'Estimate' AND estimates.contact_id = #{id})
            OR (tasks.taskable_type IN ('Invoice', 'Sale', 'Order') AND invoices.contact_id = #{id})
          )
          OR (tasks.taskable_type = 'Contact' AND tasks.taskable_id = #{id})
         }).
         order(created_at: :asc)
  end

  def aggregated_phone_calls
    PhoneCall.joins("LEFT OUTER JOIN estimates ON estimates.id = phone_calls.phoneable_id").
              joins("LEFT OUTER JOIN invoices ON invoices.id = phone_calls.phoneable_id").
              joins("LEFT OUTER JOIN inquiries ON inquiries.id = phone_calls.phoneable_id").
              where(tenant: tenant).
              where(%Q{
                (
                  (phone_calls.phoneable_type = 'Inquiry' AND inquiries.contact_id = #{id})
                  OR (phone_calls.phoneable_type = 'Estimate' AND estimates.contact_id = #{id})
                  OR (phone_calls.phoneable_type IN ('Invoice', 'Sale', 'Order') AND invoices.contact_id = #{id})
                )
                OR (phone_calls.phoneable_type = 'Contact' AND phone_calls.phoneable_id = #{id})
                OR (phone_calls.contact_id = #{id})
              }).
              order(created_at: :desc)
  end

  def aggregated_notes
    Note.joins("LEFT OUTER JOIN estimates ON estimates.id = notes.context_id").
         joins("LEFT OUTER JOIN invoices ON invoices.id = notes.context_id").
         joins("LEFT OUTER JOIN inquiries ON inquiries.id = notes.context_id").
         where(tenant: tenant).
         where(%Q{
           (
             (notes.context_type = 'Inquiry' AND inquiries.contact_id = #{id})
             OR (notes.context_type = 'Estimate' AND estimates.contact_id = #{id})
             OR (notes.context_type IN ('Invoice', 'Sale', 'Order') AND invoices.contact_id = #{id})
           )
           OR (notes.context_type = 'Contact' AND notes.context_id = #{id})
         }).
         order("notes.created_at DESC, notes.id DESC")
  end

  def aggregated_meetings
    Meeting.joins("LEFT OUTER JOIN estimates ON estimates.id = meetings.context_id").
            joins("LEFT OUTER JOIN invoices ON invoices.id = meetings.context_id").
            joins("LEFT OUTER JOIN inquiries ON inquiries.id = meetings.context_id").
            where(tenant: tenant).
            where(%Q{
              (
                (meetings.context_type = 'Inquiry' AND inquiries.contact_id = #{id})
                OR (meetings.context_type = 'Estimate' AND estimates.contact_id = #{id})
                OR (meetings.context_type IN ('Invoice', 'Sale', 'Order') AND invoices.contact_id = #{id})
              )
              OR (meetings.context_type = 'Contact' AND meetings.context_id = #{id})
            }).
            order(created_at: :desc)
  end

  def find_oldest_interaction(mbe_invoiced = false)
    if !mbe_invoiced
      oldest_invoice = Invoice.where(tenant_id: tenant.id, contact_id: id).order(source_created_at: :asc).first.try(:source_created_at)
    else
      oldest_invoice = Sale.where(tenant_id: tenant.id, contact_id: id).order(pickup_date: :asc).invoiced(mbe_invoiced).first.try(:pickup_date)
    end

    oldest_estimate = Estimate.where(tenant_id: tenant.id, contact_id: id).order(source_created_at: :asc).first.try(:source_created_at) if mbe_invoiced.present?
    oldest_shipment = Shipment.where(tenant_id: tenant.id, contact_id: id).order(shipment_date: :asc).first.try(:shipment_date)

    oldest_interaction = source_created_at

    if !oldest_invoice.nil?
      oldest_interaction = oldest_invoice if oldest_interaction.nil? || (!oldest_interaction.nil? && oldest_invoice < oldest_interaction)
    end

    if !oldest_estimate.nil?
      oldest_interaction = oldest_estimate if oldest_interaction.nil? || (!oldest_interaction.nil? && oldest_estimate < oldest_interaction)
    end

    if !oldest_shipment.nil?
      oldest_interaction = oldest_shipment if oldest_interaction.nil? || (!oldest_interaction.nil? && oldest_shipment < oldest_interaction)
    end

    oldest_interaction
  end

  def generate_sales_stats
    invoiced = Platform.is_mbe?(tenant)

    calculated_contact = Contact.calculated_order_count.
                                 calculated_last_order_date.
                                 calculated_last_pickup_date(invoiced).
                                 calculated_rolling_12_month_sales(invoiced).
                                 calculated_financial_year_sales(tenant, invoiced).
                                 calculated_financial_year_sales_ly(tenant, invoiced).
                                 calculated_financial_year_sales_ly_ly(tenant, invoiced).
                                 calculated_financial_year_cogs(tenant, invoiced).
                                 calculated_rolling_12_month_sales_ly(invoiced).
                                 calculated_rolling_12_month_sales_ly_ly(invoiced).
                                 calculated_oldest_rolling_1_invoice(invoiced).
                                 calculated_oldest_rolling_12_invoice(invoiced).
                                 calculated_oldest_rolling_12_ly_invoice(invoiced).
                                 calculated_oldest_rolling_12_ly_ly_invoice(invoiced).
                                 calculated_rolling_12_month_cogs(invoiced).
                                 calculated_average_invoice(invoiced).
                                 calculated_rolling_1_month_sales(invoiced).
                                 calculated_last_sale_pickup_date(invoiced).
                                 calculated_last_sale_order_date(invoiced).
                                 calculated_last_shipment_date.
                                 where(id: id, tenant_id: tenant.id).
                                 first
    if calculated_contact
      growth_percentage = PrintSpeak::Application.calculate_growth(calculated_contact.calculated_rolling_12_month_sales, calculated_contact.calculated_rolling_12_month_sales_ly) * 100
      growth_percentage_financial_year = PrintSpeak::Application.calculate_growth(calculated_contact.calculated_financial_year_sales, calculated_contact.calculated_financial_year_sales_ly) * 100

      self.rolling_1_month_sales = calculated_contact.calculated_rolling_1_month_sales
      self.rolling_12_month_sales = calculated_contact.calculated_rolling_12_month_sales
      self.rolling_12_month_sales_ly = calculated_contact.calculated_rolling_12_month_sales_ly
      self.rolling_12_month_sales_ly_ly = calculated_contact.calculated_rolling_12_month_sales_ly_ly
      self.latest_order_date = calculated_contact.calculated_last_order_date
      self.last_pickup_date = calculated_contact.calculated_last_pickup_date

      self.financial_year_sales = calculated_contact.calculated_financial_year_sales
      self.financial_year_sales_ly = calculated_contact.calculated_financial_year_sales_ly
      self.financial_year_sales_ly_ly = calculated_contact.calculated_financial_year_sales_ly_ly
      self.financial_year_cogs = calculated_contact.calculated_financial_year_cogs
      self.growth_percentage_financial_year = growth_percentage_financial_year.try(:round, 2).try(:to_f) || 0.0


      self.rolling_12_month_cogs = calculated_contact.calculated_rolling_12_month_cogs
      self.growth_percentage = growth_percentage.try(:round, 2).try(:to_f) || 0.0
      self.order_count = calculated_contact.calculated_order_count
      self.average_invoice = calculated_contact.calculated_average_invoice
      self.oldest_rolling_1_invoice = calculated_contact.calculated_oldest_rolling_1_invoice
      self.oldest_rolling_12_invoice = calculated_contact.calculated_oldest_rolling_12_invoice
      self.oldest_rolling_12_ly_invoice = calculated_contact.calculated_oldest_rolling_12_ly_invoice
      self.oldest_rolling_12_ly_ly_invoice = calculated_contact.calculated_oldest_rolling_12_ly_ly_invoice

      self.last_sale_order_date = calculated_contact.calculated_last_sale_order_date
      self.last_sale_pickup_date = calculated_contact.calculated_last_sale_pickup_date
      self.last_shipment_date = calculated_contact.calculated_last_shipment_date

      self.oldest_interaction = find_oldest_interaction(invoiced)

      self.last_lapsed_date = last_pickup_date
      self.last_lapsed_date = last_shipment_date if  !last_pickup_date || last_shipment_date.present? && last_shipment_date > last_pickup_date

      self.latest_order_date = last_sale_pickup_date if invoiced
      self.latest_order_date = last_shipment_date if !latest_order_date || last_shipment_date.present? && last_shipment_date > latest_order_date


      save
    end

    nil
  end

  def cogs_percentage
    if rolling_12_month_cogs.to_f != 0.0
      rolling_12_month_cogs * 100
    else
      0
    end
  end

  def lookup_address
    result = address
    if (result.nil? || (!result.nil? && result.street1.blank?)) && !try(:use_contact_address).present?
      if !company.nil? && !company.invoice_address.nil?
        result = company.invoice_address
      end
    end

    if result.nil? || (!result.nil? && result.street1.blank?)
      result = address
    end

    result
  end

  def full_address
    lookup_address.try(:full_street_address)
  end

  def is_primary?
    return false unless company.present?
    return true if company.try(:primary_contact_id) == id
    # return false if (self.deleted || self.temp).present?
    # return true if company.try(:primary_contact_id) == self.id && !self.platform_id.present?
    return true if company.try(:source_contact_id) == platform_id && platform_id.present? && !company.try(:primary_contact_id)
  end

  def self.to_csv_filtered(columns, tenant)
    bom = "\xEF\xBB\xBF"  # Defines UTF-8 ByteOrderMark to csv so Excel is happy
    CSV.generate(csv = bom, col_sep: tenant.enterprise.csv_col_sep) do |csv|
      column_titles = columns.map { |c| I18n.t_prefix(c, tenant) }
      csv << column_titles
      all.each do |result|
        csv << columns.map {
          |c| case c
              when "first_name"
                result.first_name
              when "last_name"
                result.last_name
              when "email"
                result.try(:email)
              when "company_name"
                result.try(:company).try(:name)
              when "phone"
                result.try(:phone)
              when "mobile"
                result.try(:mobile)
              when "company_phone"
                result.try(:company).try(:phone)
              when "contact_street1"
                result.try(:address).try(:street1)
              when "contact_street2"
                result.try(:address).try(:street2)
              when "contact_street3"
                result.try(:address).try(:street3)
              when "contact_city"
                result.try(:address).try(:city)
              when "contact_state"
                result.try(:address).try(:state)
              when "contact_zip"
                result.try(:address).try(:zip)
              when "company_street1"
                result.try(:company).try(:invoice_address).try(:street1)
              when "company_street2"
                result.try(:company).try(:invoice_address).try(:street2)
              when "company_street3"
                result.try(:company).try(:invoice_address).try(:street3)
              when "company_city"
                result.try(:company).try(:invoice_address).try(:city)
              when "company_state"
                result.try(:company).try(:invoice_address).try(:state)
              when "company_zip"
                result.try(:company).try(:invoice_address).try(:zip)
              when "sales_rep"
                result.sales_rep.try(:name)
              when "sales_rep_PS"
                if result.sales_rep_user.present?
                  result.sales_rep_user.try(:full_name)
                else
                  result.try(:company).try(:sales_rep_user).try(:full_name)
                end
              when "rolling_12_month_sales"
                "$" + result[c].to_f.to_s
              when "rolling_12_month_sales_ly"
                "$" + result[c].to_f.to_s
              when "latest_order_date"
                result.tenant.local_strftime(result.latest_order_date, "%%DM/%%DM/%y") if result.latest_order_date.present?
              when "last_contact"
                result.tenant.local_strftime(result[c], "%%DM/%%DM/%y") if result[c].present?
              else
                result[c]
              end
        }
      end
    end
  end

  def is_unsubscribed?
    unsubscribed || company.try(:marketing_do_not_mail)
  end

  def unsubscribes
    result = Unsubscribe.where(tenant_id: tenant_id, contact_id: id, fixed: false)

    if company.try(:marketing_do_not_mail)
      result << Unsubscribe.new(
        tenant_id: tenant_id,
        contact_id: id,
        unsub_type: "company_vision",
        email: email,
        data: {},
        fixed: false
      )
    end

    result
  end

  def unsubscribe_reasons
    result = []

    unsubscribes.each do |unsubscribe|
      if unsubscribe.unsub_type == "soft_bounce"
        bounce_count = unsubscribe.data["count"] || 0
        next if bounce_count < 3
      end
      result << Unsubscribe.definitions[unsubscribe.unsub_type].try(:[], :desc) || "Unknown"
    end

    if result.count == 0
      result << "Unknown"
    end

    result.uniq
  end

  def bad_email_type(new_email)
    result = ""

    clean_new_email = Email.clean_email(new_email)

    bad_emails = []
    new_email_definitions = Unsubscribe.definitions.select { |k, v| v[:fixable] == :new_email }.map { |k, v| k }
    if new_email_definitions.count > 0
      bad_emails = Unsubscribe.where(contact_id: id, unsub_type: new_email_definitions).pluck(:email)
    end

    bad_emails = bad_emails.map { |email| Email.clean_email(email) }

    if bad_emails.include?(clean_new_email)
      result = "bad_email"
    end

    if !result
      if Unsubscribe.on_suppression_list?(tenant, clean_new_email)
        result = "suppression_list"
      end
    end

    result
  end

  def check_fix(new_email)
    result = []

    result << "Email is blank" if new_email.blank?

    unsubscribes.each do |unsubscribe|
      definition = Unsubscribe.definitions[unsubscribe.unsub_type]
      next if definition.nil?
      case definition[:fixable]
      when :reverify
      when :any_email
      when :new_email
      when :company
        result << "Company is marked as Do Not Mail in Vision."
      when :none
        result << "This contact is permanently unsubscribed for '#{definition[:desc]}'."
      end
    end

    if Unsubscribe.on_suppression_list?(tenant, new_email)
      result << "Email is on suppression list."
    elsif !bad_email_type(new_email).blank?
      result << "Email matches a previously bad email address."
    end

    result
  end

  def fix_email(new_email, current_user)
    result = check_fix(new_email)
    if result.count == 0
      current_user_id = 0
      current_user_id = current_user.id if current_user
      found = false
      unsubscribes.each do |unsub|
        found = true
        unsub.fix(new_email, current_user)
      end
      if !found
        self.unsubscribed = false
        save
      end
    end
    result
  end

  def unsubscribe(type, data: {}, propagate: nil)
    mark_unsubbed = true
    unsub = Unsubscribe.find_or_initialize_by(
      tenant_id: tenant_id,
      contact_id: id,
      unsub_type: type,
      email: email,
      fixed: false
    )
    unsub.data = {} if unsub.data.nil?
    unsub.data.merge!(data.stringify_keys) { |key, v1, v2| v1.is_a?(Array) ? (v1 + v2).uniq : v2 }
    if type == "soft_bounce"
      if unsub.data["count"].blank?
        unsub.data["count"] = 1
        mark_unsubbed = false
      else
        unsub.data["count"] += 1
        if unsub.data["count"] < 3
          mark_unsubbed = false
        end
      end
    end
    unsub.save
    self.unsubscribed = true if mark_unsubbed
    save
    if propagate != false && Unsubscribe.definitions[type][:propagates] == true
      unsub.propagate(data)
    end
  end

  def self.lead_to_csv_filtered(columns, lead_assigned_items, tenant)
    bom = "\xEF\xBB\xBF" # Defines UTF-8 ByteOrderMark to csv so Excel is happy
    CSV.generate(csv = bom, col_sep: tenant.enterprise.csv_col_sep) do |csv|
      desired_columns = columns.map { |c| I18n.t_prefix(c, tenant) }
      csv << desired_columns
      all.each do |result|

        lead_assigned_item = lead_assigned_items.map { |item| item if item["id"] == "#{result.id}" }.compact[0] if lead_assigned_items.present?

        csv << columns.map {
          |c| case c
              when "first_name"
                result.first_name
              when "last_name"
                result.last_name
              when "email"
                result.try(:email)
              when "mobile"
                result.try(:mobile)
              when "sales_rep"
                result.try(:sales_rep).try(:name)
              when "company_name"
                result.try(:company).try(:name)
              when "lead_street1"
                result.try(:address).try(:street1)
              when "lead_street2"
                result.try(:address).try(:street2)
              when "lead_street3"
                result.try(:address).try(:street3)
              when "lead_city"
                result.try(:address).try(:city)
              when "lead_state"
                result.try(:address).try(:state)
              when "lead_zip"
                result.try(:address).try(:zip)
              when "company_street1"
                result.try(:company).try(:invoice_address).try(:street1)
              when "company_street2"
                result.try(:company).try(:invoice_address).try(:street2)
              when "company_street3"
                result.try(:company).try(:invoice_address).try(:street3)
              when "company_city"
                result.try(:company).try(:invoice_address).try(:city)
              when "company_state"
                result.try(:company).try(:invoice_address).try(:state)
              when "company_zip"
                result.try(:company).try(:invoice_address).try(:zip)
              when "lead_type"
                result.try(:lead_type).try(:name)
              when "lead_status"
                result.try(:prospect_status).try(:name)
              when "estimates"
                "$" + lead_assigned_item["estimates_grand_total"].to_f.to_s
              when "orders"
                "$" + lead_assigned_item["orders_grand_total"].to_f.to_s
              when "next_activity"
                result.next_activity_due["type"].try(:camelcase).to_s
              when "due_date"
                result.next_activity_due["due"].to_s
              else
                result[c]
              end
        }
      end
    end
  end

  def self.update_rolling_sales(tenant)
    # UPDATE contacts
    # SET oldest_rolling_1_invoice = calculated_contacts.calculated_oldest_rolling_1_invoice,
    #     oldest_rolling_12_invoice = calculated_contacts.calculated_oldest_rolling_12_invoice,
    #     oldest_rolling_12_ly_invoice = calculated_contacts.calculated_oldest_rolling_12_ly_invoice,
    #     oldest_rolling_12_ly_ly_invoice = calculated_contacts.calculated_oldest_rolling_12_ly_ly_invoice
    # FROM (
    #   SELECT contacts.id,
    #   (
    #     SELECT
    #       invoices.pickup_date
    #     FROM
    #       "invoices"
    #     WHERE
    #       ( voided = FALSE OR voided IS NULL )
    #       AND "invoices"."deleted" = 'f'
    #       AND ( "invoices"."pickup_date" IS NOT NULL )
    #       AND ( invoices.contact_id = contacts.ID )
    #       AND ( invoices.pickup_date >= (NOW()::DATE + interval '1 day') - interval '1 month' )
    #     ORDER BY
    #       "invoices"."pickup_date" ASC
    #       LIMIT 1
    #   ) AS calculated_oldest_rolling_1_invoice,
    #   (
    #     SELECT
    #       invoices.pickup_date
    #     FROM
    #       "invoices"
    #     WHERE
    #       ( voided = FALSE OR voided IS NULL )
    #       AND "invoices"."deleted" = 'f'
    #       AND ( "invoices"."pickup_date" IS NOT NULL )
    #       AND ( invoices.contact_id = contacts.ID )
    #       AND ( invoices.pickup_date >= (NOW()::DATE + interval '1 day') - interval '1 year' )
    #     ORDER BY
    #       "invoices"."pickup_date" ASC
    #       LIMIT 1
    #   ) AS calculated_oldest_rolling_12_invoice,
    #   (
    #     SELECT
    #       invoices.pickup_date
    #     FROM
    #       "invoices"
    #     WHERE
    #       ( voided = FALSE OR voided IS NULL )
    #       AND "invoices"."deleted" = 'f'
    #       AND ( "invoices"."pickup_date" IS NOT NULL )
    #       AND ( invoices.contact_id = contacts.ID )
    #       AND ( invoices.pickup_date >= (NOW()::DATE + interval '1 day') - interval '2 years' )
    #     ORDER BY
    #       "invoices"."pickup_date" ASC
    #       LIMIT 1
    #   ) AS calculated_oldest_rolling_12_ly_invoice,
    #   (
    #     SELECT
    #       invoices.pickup_date
    #     FROM
    #       "invoices"
    #     WHERE
    #       ( voided = FALSE OR voided IS NULL )
    #       AND "invoices"."deleted" = 'f'
    #       AND ( "invoices"."pickup_date" IS NOT NULL )
    #       AND ( invoices.contact_id = contacts.ID )
    #       AND ( invoices.pickup_date >= (NOW()::DATE + interval '1 day') - interval '3 years' )
    #     ORDER BY
    #       "invoices"."pickup_date" ASC
    #       LIMIT 1
    #   ) AS calculated_oldest_rolling_12_ly_ly_invoice
    #   FROM contacts
    #   ORDER BY contacts.id ASC
    #   LIMIT 1000000
    #   OFFSET 0
    # ) AS calculated_contacts
    # WHERE contacts.id = calculated_contacts.id
    # AND (
    #   contacts.oldest_rolling_1_invoice IS DISTINCT FROM calculated_contacts.calculated_oldest_rolling_1_invoice
    #   OR contacts.oldest_rolling_12_invoice IS DISTINCT FROM calculated_contacts.calculated_oldest_rolling_12_invoice
    #   OR contacts.oldest_rolling_12_ly_invoice IS DISTINCT FROM calculated_contacts.calculated_oldest_rolling_12_ly_invoice
    #   OR contacts.oldest_rolling_12_ly_ly_invoice IS DISTINCT FROM calculated_contacts.calculated_oldest_rolling_12_ly_ly_invoice
    # );

    # CREATE INDEX CONCURRENTLY index_contacts_tenant_oldest_rolling ON contacts (tenant_id, oldest_rolling_1_invoice, oldest_rolling_12_invoice, oldest_rolling_12_ly_invoice, oldest_rolling_12_ly_ly_invoice, id) WHERE oldest_rolling_1_invoice IS NOT NULL OR oldest_rolling_12_invoice IS NOT NULL OR oldest_rolling_12_ly_invoice IS NOT NULL OR oldest_rolling_12_ly_ly_invoice IS NOT NULL

    rolling_1_falloff = (Date.tomorrow - 1.month)
    rolling_12_falloff = (Date.tomorrow - 1.year)
    rolling_12_ly_falloff = (Date.tomorrow - 2.years)
    rolling_12_ly_ly_falloff = (Date.tomorrow - 3.years)

    rolling_1_falloff_next_day = rolling_1_falloff + 1.day
    rolling_12_falloff_next_day = rolling_12_falloff + 1.day
    rolling_12_ly_falloff_next_day = rolling_12_ly_falloff + 1.day
    rolling_12_ly_ly_falloff_next_day = rolling_12_ly_ly_falloff + 1.day

    contacts_query = %Q{
      SELECT contacts.id, contacts.oldest_rolling_1_invoice, contacts.oldest_rolling_12_invoice, contacts.oldest_rolling_12_ly_invoice, contacts.oldest_rolling_12_ly_ly_invoice
      FROM contacts
      WHERE contacts.tenant_id = #{tenant.id}
      AND (
        (contacts.oldest_rolling_1_invoice IS NOT NULL AND contacts.oldest_rolling_1_invoice < #{ActiveRecord::Base::sanitize(rolling_1_falloff_next_day)})
        OR (contacts.oldest_rolling_12_invoice IS NOT NULL AND contacts.oldest_rolling_12_invoice < #{ActiveRecord::Base::sanitize(rolling_12_falloff_next_day)})
        OR (contacts.oldest_rolling_12_ly_invoice IS NOT NULL AND contacts.oldest_rolling_12_ly_invoice < #{ActiveRecord::Base::sanitize(rolling_12_ly_falloff_next_day)})
        OR (contacts.oldest_rolling_12_ly_ly_invoice IS NOT NULL AND contacts.oldest_rolling_12_ly_ly_invoice < #{ActiveRecord::Base::sanitize(rolling_12_ly_ly_falloff_next_day)})
      )
    }

    next_schedule = nil
    contacts = Contact.find_by_sql(contacts_query)

    contacts.each do |contact|
      if (!contact.oldest_rolling_1_invoice.nil? && contact.oldest_rolling_1_invoice < rolling_1_falloff) ||
         (!contact.oldest_rolling_12_invoice.nil? && contact.oldest_rolling_12_invoice < rolling_12_falloff) ||
         (!contact.oldest_rolling_12_ly_invoice.nil? && contact.oldest_rolling_12_ly_invoice < rolling_12_ly_falloff) ||
         (!contact.oldest_rolling_12_ly_ly_invoice.nil? && contact.oldest_rolling_12_ly_ly_invoice < rolling_12_ly_ly_falloff)
        Event.queue(tenant, "contact_sales", data: {contact_id: contact.id})
      end

      if !contact.oldest_rolling_1_invoice.nil? && contact.oldest_rolling_1_invoice >= rolling_1_falloff && contact.oldest_rolling_1_invoice < (rolling_1_falloff_next_day)
        if next_schedule.nil?
          next_schedule = contact.oldest_rolling_1_invoice + 1.month
        else
          next_schedule = contact.oldest_rolling_1_invoice + 1.month if (contact.oldest_rolling_1_invoice + 1.month) < next_schedule
        end
      end

      if !contact.oldest_rolling_12_invoice.nil? && contact.oldest_rolling_12_invoice >= rolling_12_falloff && contact.oldest_rolling_12_invoice < (rolling_12_falloff_next_day)
        if next_schedule.nil?
          next_schedule = contact.oldest_rolling_12_invoice + 1.year
        else
          next_schedule = contact.oldest_rolling_12_invoice + 1.year if (contact.oldest_rolling_12_invoice + 1.year) < next_schedule
        end
      end

      if !contact.oldest_rolling_12_ly_invoice.nil? && contact.oldest_rolling_12_ly_invoice >= rolling_12_ly_falloff && contact.oldest_rolling_12_ly_invoice < (rolling_12_ly_falloff_next_day)
        if next_schedule.nil?
          next_schedule = contact.oldest_rolling_12_ly_invoice + 2.years
        else
          next_schedule = contact.oldest_rolling_12_ly_invoice + 2.years if (contact.oldest_rolling_12_ly_invoice + 2.years) < next_schedule
        end
      end

      if !contact.oldest_rolling_12_ly_ly_invoice.nil? && contact.oldest_rolling_12_ly_ly_invoice >= rolling_12_ly_ly_falloff && contact.oldest_rolling_12_ly_ly_invoice < (rolling_12_ly_ly_falloff_next_day)
        if next_schedule.nil?
          next_schedule = contact.oldest_rolling_12_ly_ly_invoice + 3.years
        else
          next_schedule = contact.oldest_rolling_12_ly_ly_invoice + 3.years if (contact.oldest_rolling_12_ly_ly_invoice + 3.years) < next_schedule
        end
      end
    end

    if !next_schedule.nil?
      Event.queue(tenant, "contact_rolling_sales", schedule_date: next_schedule + 1.minute, unique_for: ["scheduled"])
    end
  end

  def create_next_activity
    next_activity_task
    next_activity_meeting
    next_activity_nextactivities

    compute_next_date
  end

  def compute_next_date
    next_activity["next_date"] = nil
    next_activity["next_type"] = nil
    next_activity["next_id"] = nil

    next_activity.each do |item|
      next unless item[1].present?
      next unless %w[task_date meeting_date call_date email_date].include? item[0]

      if !next_activity["next_date"].present? || next_activity["next_date"] > item[1]
        next_activity["next_date"] = item[1]
        next_activity["next_type"] = item[0].split("_")[0]
        next_activity["next_id"] = next_activity[item[0].split("_")[0] + "_id"]
      end
    end
  end

  def next_activity_task
    find_next_task = aggregated_tasks.where.not(status: "Completed").where.not(status: "Cancelled").select("tasks.*", "end_date as next_activity_date").reorder("tasks.end_date ASC").first

    if find_next_task.present?
      next_activity["task_id"] = find_next_task.id
      next_activity["task_date"] = find_next_task.next_activity_date
    else
      next_activity["task_id"] = nil
      next_activity["task_date"] = nil
    end
  end

  def next_activity_meeting
    find_next_meeting = aggregated_meetings.where(status: "live").select("meetings.*", "start_date as next_activity_date").reorder("start_date ASC").first

    if find_next_meeting.present?
      next_activity["meeting_id"] = find_next_meeting.id
      next_activity["meeting_date"] = find_next_meeting.next_activity_date
    else
      next_activity["meeting_id"] = nil
      next_activity["meeting_date"] = nil
    end
  end

  def next_activity_nextactivities
    next_call_email = next_activities.where(status: "active").select("next_activities.*", "scheduled as next_activity_date", "context_type as next_activity_type").first

    if next_call_email.present?
      if next_call_email.next_activity_type == "Call"
        next_activity["call_id"] = next_call_email.id
        next_activity["call_date"] = next_call_email.next_activity_date
        next_activity["email_id"] = nil
        next_activity["email_date"] = nil
      end

      if next_call_email.next_activity_type == "Email"
        next_activity["email_id"] = next_call_email.id
        next_activity["email_date"] = next_call_email.next_activity_date
        next_activity["call_id"] = nil
        next_activity["call_date"] = nil
      end
    else
      next_activity["call_id"] = nil
      next_activity["call_date"] = nil
      next_activity["email_id"] = nil
      next_activity["email_date"] = nil
    end
  end

  def next_activity_item
    lead_type.prospect_status_items.where(prospect_status_id: prospect_status_id)
    .joins("LEFT JOIN prospect_status_item_contacts ON prospect_status_item_contacts.prospect_status_item_id = prospect_status_items.id AND prospect_status_item_contacts.contact_id = #{id}")
    .joins("LEFT JOIN prospect_statuses ON prospect_statuses.id = prospect_status_items.prospect_status_id")
    .where('prospect_statuses.prospect_status_version_id': current_prospect_status_version.id)
    .where('prospect_status_item_contacts.status': 2).first if lead_type
  end

  def set_first_activity_item(current_user)
      if lead_stage_last_item
        @next_item = lead_stage_last_item.prospect_status_item.lower_item
      else
        @next_item = ProspectStatusItem.where(prospect_status_id: prospect_status_id, lead_type_id: lead_type_id).first
      end

      if @next_item.present?
        if !ProspectStatusItemContact.where(prospect_status_item_id: @next_item.id, contact_id:  id, tenant_id: tenant_id, status: 2).first
          prospect_status_item_contact = ProspectStatusItemContact.create(
            contact_id: id,
            start_date: Time.zone.now(),
            due_date: Time.zone.now() + @next_item.try(:completion_time).days,
            prospect_status_item_id: @next_item.id,
            tenant_id: tenant_id,
            status: 2
          )

          prospect_status_item_contact.task_generate(current_user) if prospect_status_item_contact.prospect_status_item.item_type == "Task"
          prospect_status_item_contact.meeting_generate(current_user) if prospect_status_item_contact.prospect_status_item.item_type == "Meeting"

          skip_previous_items(prospect_status_item_contact)
        end
      end
  end

  def next_activity_due
    item_hash = {}
    contact_prospect_status_item =  next_activity_item
    next_activity_item_contact = contact_prospect_status_item.prospect_status_item_contact(id) if contact_prospect_status_item

    start_date = next_activity_item_contact.try(:start_date)
    due_date = next_activity_item_contact.try(:due_date)

    next_activity_date  = next_activity["next_date"].try(:in_time_zone)

    if next_activity_date.present? && due_date && due_date.try(:in_time_zone) <= next_activity_date || !next_activity_date.present? && due_date
      item_hash["type"] = contact_prospect_status_item.try(:item_type)
      item_hash["start"] = tenant.local_strftime(next_activity_item_contact.try(:start_date).try(:in_time_zone, tenant.time_zone), "%%DM-%%DM-%Y")
      item_hash["due"] = tenant.local_strftime(next_activity_item_contact.try(:due_date).try(:in_time_zone, tenant.time_zone), "%%DM-%%DM-%Y")
    elsif next_activity_date
    item_hash["type"] =  next_activity["next_type"]
      item_hash["due"] =  tenant.local_strftime(next_activity["next_date"].try(:in_time_zone, tenant.time_zone), "%%DM-%%DM-%Y")
      # item_hash['due'] = next_activity_item_contact.try(:due_date)
    end

    item_hash
  end

  def display_lead_statuses
    available_lead_statuses = prospect_status.prospect_status_version.prospect_statuses
    available_lead_statuses.joins("LEFT JOIN prospect_status_items ON prospect_status_items.prospect_status_id = prospect_statuses.id AND prospect_status_items.lead_type_id = #{ lead_type_id}").where.not('prospect_status_items.id': nil).group("prospect_statuses.id")
  end

  def available_lead_statuses
    if tenant.use_new_lead
      available_lead_statuses = lead_type.prospect_status_version.prospect_statuses
      available_lead_statuses.joins("LEFT JOIN prospect_status_items ON prospect_status_items.prospect_status_id = prospect_statuses.id AND prospect_status_items.lead_type_id = #{ lead_type_id}").where.not('prospect_status_items.id': nil).group("prospect_statuses.id")
    else
      available_lead_statuses = lead_type.prospect_status_version.prospect_statuses
    end
  end

  def next_available_status
    current_prospect_status_version.prospect_statuses.joins(:prospect_status_items).where("prospect_statuses.position > (?)", prospect_status.position).first
  end

  def previous_available_status
    current_prospect_status_version.prospect_statuses.joins(:prospect_status_items).where("prospect_statuses.position < (?)", prospect_status.position).reorder("prospect_statuses.position DESC").first
  end

  def lead_stage_items
      prospect_status_item_contacts
      .joins("LEFT JOIN prospect_status_items ON prospect_status_items.id = prospect_status_item_contacts.prospect_status_item_id")
      .joins("LEFT JOIN prospect_statuses ON prospect_statuses.id = prospect_status_items.prospect_status_id")
      .where('prospect_status_items.lead_type_id': lead_type_id)
      .where('prospect_statuses.prospect_status_version_id': current_prospect_status_version.id)
      .group("prospect_status_item_contacts.id")
  end

  def lead_stage_last_item
    prospect_status_item_contacts
      .joins("LEFT JOIN prospect_status_items ON prospect_status_items.id = prospect_status_item_contacts.prospect_status_item_id")
      .joins("LEFT JOIN prospect_statuses ON prospect_statuses.id = prospect_status_items.prospect_status_id")
      .where('prospect_statuses.prospect_status_version_id': current_prospect_status_version.id)
      .where.not('prospect_status_item_contacts.status': 2)
      .where('prospect_status_items.lead_type_id': lead_type_id)
      .where('prospect_status_items.prospect_status_id': prospect_status_id)
      .order("prospect_status_items.position DESC")
      .group("prospect_status_item_contacts.id, prospect_status_items.position")
      .first
  end

  def completed_lead_process?
    return true if lead_type.prospect_status_items.where(prospect_status_id: current_prospect_status_version.prospect_statuses.joins(:prospect_status_items).pluck(:id)).count == lead_stage_items.length
  end

  def skip_previous_items(current_item_contact)
    # SET ALL PREVIOUS STATUS ITEMS ITEMS AS SKIPPED FOR SPECIFIC VERSION STATUSES
    current_prospect_status_version.prospect_statuses.where("prospect_statuses.position < (?)",  current_item_contact.prospect_status_item.prospect_status.position).each do |status|
      lead_type.prospect_status_items.where(prospect_status_id: status.id).each do |item|
        process_skip_item(item)
      end
    end

    # SET CURRENT STATUS PREVIOUS ITEMS AS SKIPPED
    lead_type.prospect_status_items.where(prospect_status_id: current_item_contact.prospect_status_item.prospect_status_id).where("position < (?)", current_item_contact.prospect_status_item.position).each do |item|
      process_skip_item(item)
    end
  end

  def skip_previous_status_items
   # SET ALL PREVIOUS STATUS ITEMS ITEMS AS SKIPPED FOR SPECIFIC VERSION STATUSES
    current_prospect_status_version.prospect_statuses.where("prospect_statuses.position < (?)",  prospect_status.position).each do |status|
      lead_type.prospect_status_items.where(prospect_status_id: status.id).each do |item|
        process_skip_item(item)
      end
    end
  end

  def process_skip_item(item)
    prospect_status_item_contact =  ProspectStatusItemContact.where(prospect_status_item: item, contact: id).first

    if prospect_status_item_contact.present?
      prospect_status_item_contact.update_attributes(status: 3) if prospect_status_item_contact.status == 0 || prospect_status_item_contact.status == 2

      task = Task.where(taskable_type: "Contact", taskable_id: prospect_status_item_contact.contact_id, prospect_status_item_contact_id: prospect_status_item_contact.id).first
      if task && prospect_status_item_contact.status == 3
        task.status = "Cancelled"
        task.save
      end
    else
      prospect_status_item_contact =  ProspectStatusItemContact.create({
        prospect_status_item_id: item.id,
        contact_id: id,
        start_date: Time.zone.now(),
        due_date: Time.zone.now(),
        tenant_id: tenant_id,
        status: 3
      })
    end

    prospect_status_item_contact
  end

  def current_prospect_status_version
    prospect_status.prospect_status_version
  end

  def compute_activity_progress
    return false if lead_type.status == "Old" || !lead_type

    lead_items_count = lead_type.prospect_status_items.where(prospect_status_id: current_prospect_status_version.prospect_statuses.pluck(:id)).count
    final_activity_items = lead_stage_items.length if lead_stage_items

    if final_activity_items > 0
      progress = (final_activity_items.to_f / lead_items_count.to_f * 100).round(0) if final_activity_items.to_f > 0 && lead_items_count.to_f > 0
    else
      progress = 0
    end

    self.conv_prob = progress
    save
  end

  def privacy_state(option)
    result = -1

    if privacy_data.present? && privacy_data.key?(option) && privacy_data[option].present? && privacy_data[option]["state"].present?
      result = privacy_data[option]["state"].try(:to_i) || -1
    end

    result
  end

  def privacy_state_key(option)
    case privacy_state(option)
    when -1
      "empty"
    when 0
      "no"
    when 1
      "yes"
    end
  end

  def privacy_date(option)
    result = nil

    if privacy_data.present? && privacy_data.key?(option) && privacy_data[option].present? && privacy_data[option]["date"].present?
      result = privacy_data[option]["date"].try(:to_datetime).try(:to_date)
    end

    result
  end
end
