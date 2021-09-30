class Company < ActiveRecord::Base
  include EstimateConvertable
  include ApiLoggable
  include Excludable
  include Bookmarkable
  include Categorizable

  # geocoded_by :address_lookup

  enum prospect_sentiment: { bad: 0, normal: 1, great: 2 }

  has_one :location, class_name: "Location", foreign_key: "id", primary_key: "location_user_id"
  belongs_to :sales_rep_user, class_name: "User"
  belongs_to :primary_contact, ->  (company) {
    if Platform.is_mbe?(company)
      unscope(:where).where.not(deleted: true).where(id: company.primary_contact_id)
    else
      unscope(:where).where("id = ? OR (platform_id = ? AND platform_id IS NOT NULL)", company.primary_contact_id, company.source_contact_id).where.not(deleted: true).where.not(temp: true)
    end
  }, class_name: "Contact"

  has_many :account_history_data, class_name: "AccountHistoryData"
  has_many :estimates, inverse_of: :company
  has_many :invoices, inverse_of: :company
  has_many :sales, inverse_of: :company
  has_many :orders, inverse_of: :company
  has_many :statistics
  has_many :contacts
  has_many :tasks, as: :taskable
  has_many :phone_calls, as: :phoneable
  has_many :activities
  has_many :notes, as: :context
  belongs_to :tenant, inverse_of: :companies
  belongs_to :statement_address, class_name: "Address"
  belongs_to :invoice_address, class_name: "Address"
  belongs_to :prospect_status
  belongs_to :lead_type
  has_many :inquiries

  include Scopes::CompanyScopes

  attr_accessor :new_tag_category_id

  def sales_rep
    SalesRep.where("platform_id = ? AND tenant_id = ?", sales_rep_platform_id, tenant_id).where(deleted: false).first
  end

  def sales_rep_name
    sales_rep.try(:name)
  end

  def self.to_csv(options = {})
    CSV.generate(options, col_sep: tenant.enterprise.csv_col_sep) do |csv|
      csv << column_names
      all.each do |invoice|
        csv << invoice.attributes.values_at(*column_names)
      end
    end
  end

  def self.to_csv_filtered(columns, tenant)
    bom = "\xEF\xBB\xBF"  # Defines UTF-8 ByteOrderMark to csv so Excel is happy
    CSV.generate(csv = bom, col_sep: tenant.enterprise.csv_col_sep) do |csv|
      column_titles = columns.map { |c| I18n.t_prefix(c, tenant) }
      csv << column_titles
      all.each do |result|
        csv << columns.map {
          |c| case c
              when "sales_rep"
                result.sales_rep_name
              when "sales_rep_PS"
                result.sales_rep_user.try(:full_name)
              when "rolling_12_month_sales"
                "$" + result[c].to_f.to_s
              when "rolling_12_month_sales_ly"
                "$" + result[c].to_f.to_s
              when "street1"
                result.invoice_address.street1.to_s if result.invoice_address.try(:street1).present?
              when "street2"
                result.invoice_address.street2.to_s if result.invoice_address.try(:street2).present?
              when "street3"
                result.invoice_address.street3.to_s if result.invoice_address.try(:street3).present?
              when "city"
                result.invoice_address.city.to_s if result.invoice_address.try(:city).present?
              when "state"
                result.invoice_address.state.to_s if result.invoice_address.try(:state).present?
              when "zip"
                result.invoice_address.zip.to_s if result.invoice_address.try(:zip).present?
              when "balance"
                "$" + result[c].to_f.to_s
              when "last_order"
                result.tenant.local_strftime(result.last_order_date, "%%DM/%%DM/%y") if result.last_order_date.present?
              when "last_contact"
                result.tenant.local_strftime(result[c], "%%DM/%%DM/%y") if result[c].present?
              else
                result[c]
              end
        }
      end
    end
  end

  def self.web_to_csv(data, tenant)
    CSV.generate(col_sep: tenant.enterprise.csv_col_sep) do |csv|
      desired_columns = ["Name", "First Web", "Last Web", "Orders", "Sales", "Total Sales", "Orders LY", "Sales LY", "AVG Order"]
      csv << desired_columns
      data.map do |company|
        csv << [
          "#{ company['company_name'] }",
          "#{ tenant.local_strftime(company['first_invoice_date'], '%%DM/%%DM/%y') if company['first_invoice_date'] }",
          "#{ tenant.local_strftime(company['last_invoice_date'], '%%DM/%%DM/%y') if company['last_invoice_date'] }",
          "#{ company['invoice_count'] }",
          "$ #{ company['invoice_value'] }",
          "$ #{ company['invoice_total_value'] }",
          "#{ company['invoice_count_ly'] }",
          "$ #{ company['invoice_value_ly'].to_f }",
          "$ #{ company['invoice_value'].to_f / company['invoice_count'].to_f || 0 }"
        ]
      end
    end
  end

  def self.sales_tag_to_csv(data, tenant)
    CSV.generate(col_sep: tenant.enterprise.csv_col_sep) do |csv|
      desired_columns = ["Name", "# of Invoices", "Tagged Sales", "Total Sales", "# of Invoices LY", "Tagged Sales LY", "AVG Order"]
      csv << desired_columns
      data.map do |company|
        csv << [
          "#{ company['company_name'] }",
          "#{ company['invoice_count'] }",
          "$ #{ company['invoice_value'] }",
          "$ #{ company['invoice_total_value'] }",
          "#{ company['invoice_count_ly'] }",
          "$ #{ company['invoice_value_ly'].to_f }",
          "$ #{ company['invoice_value'].to_f / company['invoice_count'].to_f || 0 }"
        ]
      end
    end
  end

  def fy_count(start_date = (Time.zone.now - 1.years) , end_date = (Time.zone.now))
    count = estimates.where(ordered_date: start_date..end_date).count
    # estimates.where("status = ''").count if count == 0 || 0
  end

  def get_avg_estimate_conversion_fy
    end_date = Date.today
    start_date = end_date - 1.year

    if won_estimates(start_date, end_date) > 0
      won_estimates = won_estimates(start_date, end_date).to_f
      total = won_estimates(start_date, end_date).to_f + lost_estimates(start_date, end_date).to_f + pending_estimates(start_date, end_date).to_f

      if won_estimates > 0 && total > 0
        (won_estimates / total * 100).round(2)
      else
        0
      end
    else
      0
    end
  end

  def self.average_estimate_conversion_by_company_id(company_ids)
    company_status_counts = Estimate.group(:company_id, :status).where(company_id: company_ids).pluck("company_id, status, count(*)").each_with_object({}) do |(company_id, status, count), result|
      result[company_id] ||= Hash.new { 0 }
      result[company_id][status] = count
    end

    company_status_counts.each_with_object({}) do |(company_id, status_counts), result|
      result[company_id] = status_counts["Won"].to_f / (status_counts["Won"] + status_counts["Lost"] + status_counts[""]) if company_id
    end
  end

  def display_name
    name.blank? ? "<not entered>" : name
  end

  def self.account_types
    %w[charge_acct cash_only cash_check_credit full_deposit credit_card_on_file]
  end

  def display_account_type
    I18n.dict("models.company.account_types", account_type, keys: self.class.account_types)
  end

  def self.statuses
    %w[CustomerStatusCurrent CustomerStatusNew CustomerStatusFrozen CustomerStatusPastDue CustomerStatusInactive CustomerStatusDelinquent]
  end

  def display_status
    I18n.dict("models.company.statuses", status, keys: self.class.statuses)
  end

  def most_common_domain_name
    domains = contacts.where(temp: false, deleted: false).where.not(email: nil).where.not(email: "").map { |contact| contact.email.try(:split, "@").try(:last) }
    domains.group_by(&:itself).values.max_by(&:size).try(:first)
  end

  def website_most_common_domain_name
    domain = ""

    if custom_data.present? && custom_data["domain"].present?
      url = custom_data["domain"].strip

      if !(url.match(/^http:\/\//) || url.match(/^https:\/\//))
        url = "http://" + url
      end

      begin
        domain = URI.parse(url).host.gsub("www.", "").gsub(" ", "")
      rescue StandardError
      end
    end

    domain = most_common_domain_name if domain.blank?
    domain.gsub!(/\s+/, "") if domain.present? # return domain whitout white spaces
    domain
  end

  def allowed_clearbit_search?
    domain = website_most_common_domain_name

    return true if !has_clearbit_data.present? && domain.present? && !Printsmith::Integration::Clearbit.common_shared_domains.include?(domain)
  end

  def aggregated_tasks
    Task.joins("LEFT OUTER JOIN contacts ON contacts.id = tasks.taskable_id").
         joins("LEFT OUTER JOIN estimates ON estimates.id = tasks.taskable_id").
         joins("LEFT OUTER JOIN invoices ON invoices.id = tasks.taskable_id").
         joins("LEFT OUTER JOIN inquiries ON inquiries.id = tasks.taskable_id").
         where(tenant: tenant).
         where(%Q{
          (
            (tasks.taskable_type = 'Inquiry' AND inquiries.company_id = #{id})
            OR (tasks.taskable_type = 'Contact' AND contacts.company_id = #{id})
            OR (tasks.taskable_type = 'Estimate' AND estimates.company_id = #{id})
            OR (tasks.taskable_type IN ('Invoice', 'Sale', 'Order') AND invoices.company_id = #{id})
          )
          OR (tasks.taskable_type = 'Company' AND tasks.taskable_id = #{id})
         }).
         order(created_at: :asc)
  end

  def aggregated_phone_calls
    PhoneCall.joins("LEFT OUTER JOIN contacts ON contacts.id = phone_calls.phoneable_id").
         joins("LEFT OUTER JOIN estimates ON estimates.id = phone_calls.phoneable_id").
         joins("LEFT OUTER JOIN invoices ON invoices.id = phone_calls.phoneable_id").
         joins("LEFT OUTER JOIN inquiries ON inquiries.id = phone_calls.phoneable_id").
         where(tenant: tenant).
         where(%Q{
          (
            (phone_calls.phoneable_type = 'Inquiry' AND inquiries.company_id = #{id})
            OR (phone_calls.phoneable_type = 'Contact' AND contacts.company_id = #{id})
            OR (phone_calls.phoneable_type = 'Estimate' AND estimates.company_id = #{id})
            OR (phone_calls.phoneable_type IN ('Invoice', 'Sale', 'Order') AND invoices.company_id = #{id})
          )
          OR (phone_calls.phoneable_type = 'Company' AND phone_calls.phoneable_id = #{id})
         }).
         order(created_at: :desc)
  end

  def aggregated_notes
    Note.joins("LEFT OUTER JOIN contacts ON contacts.id = notes.context_id").
         joins("LEFT OUTER JOIN estimates ON estimates.id = notes.context_id").
         joins("LEFT OUTER JOIN invoices ON invoices.id = notes.context_id").
         joins("LEFT OUTER JOIN inquiries ON inquiries.id = notes.context_id").
         where(tenant: tenant).
         where(%Q{
          (
            (notes.context_type = 'Inquiry' AND inquiries.company_id = #{id})
            OR (notes.context_type = 'Contact' AND contacts.company_id = #{id})
            OR (notes.context_type = 'Estimate' AND estimates.company_id = #{id})
            OR (notes.context_type IN ('Invoice', 'Sale', 'Order') AND invoices.company_id = #{id})
          )
          OR (notes.context_type = 'Company' AND notes.context_id = #{id})
         }).
         order("created_at DESC, id DESC")
  end

  def aggregated_meetings
    Meeting.joins("LEFT OUTER JOIN contacts ON contacts.id = meetings.context_id").
            joins("LEFT OUTER JOIN estimates ON estimates.id = meetings.context_id").
            joins("LEFT OUTER JOIN invoices ON invoices.id = meetings.context_id").
            joins("LEFT OUTER JOIN inquiries ON inquiries.id = meetings.context_id").
            where(tenant: tenant).
            where(%Q{
              (
                (meetings.context_type = 'Inquiry' AND inquiries.company_id = #{id})
                OR (meetings.context_type = 'Contact' AND contacts.company_id = #{id})
                OR (meetings.context_type = 'Estimate' AND estimates.company_id = #{id})
                OR (meetings.context_type IN ('Invoice', 'Sale', 'Order') AND invoices.company_id = #{id})
              )
              OR (meetings.context_type = 'Company' AND meetings.context_id = #{id})
             }).
            order(created_at: :desc)
  end

  def campaigns
    Campaign.joins(:messages).joins("JOIN contacts ON contacts.id = campaign_messages.contact_id").where(tenant_id: tenant_id, contacts: {company_id: id}).where.not(parent_id: nil).group("campaigns.id")
  end

  def find_oldest_interaction(mbe_invoiced = false)
    if !mbe_invoiced
      oldest_invoice = Invoice.where(tenant_id: tenant.id, company_id: id).order(source_created_at: :asc).first.try(:source_created_at)
    else
      oldest_invoice = Sale.where(tenant_id: tenant.id, company_id: id).order(pickup_date: :asc).invoiced(mbe_invoiced).first.try(:pickup_date)
    end

    oldest_estimate = Estimate.where(tenant_id: tenant.id, company_id: id).order(source_created_at: :asc).first.try(:source_created_at) if mbe_invoiced.present?
    oldest_shipment = Shipment.where(tenant_id: tenant.id, company_id: id).order(shipment_date: :asc).first.try(:shipment_date)

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
    #TODO: eventually move Common::Statistics::CompanyRanking into this somehow
    invoiced = Platform.is_mbe?(tenant)

    calculated_company = Company.select("id, deleted, rolling_12_month_sales, rolling_12_month_sales_ly, last_order_date, last_pickup_date, rolling_12_month_cogs, growth_percentage, order_count, balance, last_sale_order_date, last_sale_pickup_date, last_shipment_date, oldest_interaction").
                                 calculated_order_count.
                                 calculated_last_order_date.
                                 calculated_last_pickup_date.
                                 calculated_last_sale_pickup_date(invoiced).
                                 calculated_last_sale_order_date(invoiced).
                                 calculated_last_shipment_date.
                                 calculated_first_sale_date(invoiced).
                                 calculated_balance(invoiced).
                                 where(id: id, tenant_id: tenant.id).
                                 first

    if calculated_company
      # growth_percentage = PrintSpeak::Application.calculate_growth(calculated_company.rolling_12_month_sales, calculated_company.rolling_12_month_sales_ly) * 100

      self.last_order_date = calculated_company.calculated_last_order_date
      self.last_pickup_date = calculated_company.calculated_last_pickup_date
      self.first_sale_at = calculated_company.calculated_first_sale_date

      self.last_sale_order_date = calculated_company.calculated_last_sale_order_date
      self.last_sale_pickup_date = calculated_company.calculated_last_sale_pickup_date
      self.last_shipment_date = calculated_company.calculated_last_shipment_date

      # self.growth_percentage = growth_percentage.try(:round, 2).try(:to_f) || 0
      self.order_count = calculated_company.calculated_order_count
      self.balance = calculated_company.calculated_balance if Platform.is_mbe?(tenant)
      self.oldest_interaction = find_oldest_interaction(invoiced)

      self.last_order_date = last_sale_pickup_date if invoiced
      self.last_order_date = last_shipment_date if !last_order_date || last_shipment_date.present? && last_shipment_date > last_order_date

      save
    end

    nil
  end

  def info(*args)
    result = nil

    custom = custom_data
    clearbit = clearbit_data
    args.each do |arg|
      custom = custom.try(:[], arg)
      clearbit = clearbit.try(:[], arg)
    end
    if custom.present?
      result = custom
    else
      result = clearbit if clearbit.present?
    end

    result
  end

  def bulk_send_contact
    result = nil
    ap_contact = Contact.where(tenant: tenant, id: account_payable_id).first

    statement_contact = primary_contact
    statement_contact = Contact.where(tenant: tenant, company_id: id).order(source_created_at: :asc).first unless statement_contact.present?
    statement_contact = Contact.where(tenant: tenant, platform_id: source_billtocontact_id).first if !source_billtocontact_id.nil?
    result = statement_contact
    result = ap_contact if statement_contact.try(:email).blank? || (send_invoice_ap_contact && !ap_contact.try(:email).blank?)
    result
  end

  def is_unsubscribed?
    marketing_do_not_mail
  end

  def unsubscribe_reasons
    result = []
    result << Unsubscribe.definitions["company_vision"].try(:[], :desc) || "Unknown"
    result
  end

  def self.sectors_hash
    sector = Array.new

    CSV.parse(Company.csv_categories, col_sep: ",", headers: true) do |row|
      sector << { "name" => row[0] }
    end

    sector.uniq
  end

  def self.industry_group_hash
    industry_groups = Array.new

    CSV.parse(Company.csv_categories, col_sep: ",", headers: true) do |row|
      industry_groups << {  "name" => row[1],  "sector" => row[0] }
    end

    industry_groups.uniq
  end

  def self.industry_hash
    industry = Array.new

    CSV.parse(Company.csv_categories, col_sep: ",", headers: true) do |row|
      industry << {
        "name" => row[2],
        "industry_group" => row[1],
        "sector" => row[0]
       }
    end

    industry.uniq
  end

  def self.sub_industries_hash
    sub_industry = Array.new

    CSV.parse(Company.csv_categories, col_sep: ",", headers: true) do |row|
      sub_industry << {
        "name" => row[3],
        "industry" => row[2],
        "industry_group" => row[1],
        "sector" => row[0]
      }
    end

    sub_industry.uniq
  end

  def self.csv_categories
    'Associations,Associations,Associations,Associations
Sector,Industry Group,Industry,Sub Industry
Consumer Discretionary,Automobiles & Components,Automotive,Automotive
Consumer Discretionary,Consumer Discretionary,Consumer Discretionary,Consumer Discretionary
Consumer Discretionary,Consumer Durables & Apparel,Consumer Goods,Consumer Goods
Consumer Discretionary,Consumer Durables & Apparel,Household Durables,Consumer Electronics
Consumer Discretionary,Consumer Durables & Apparel,Household Durables,Household Appliances
Consumer Discretionary,Consumer Durables & Apparel,Household Durables,Photography
Consumer Discretionary,Consumer Durables & Apparel,Leisure Products,Leisure Facilities
Consumer Discretionary,Consumer Durables & Apparel,Leisure Products,Sporting Goods
Consumer Discretionary,Consumer Durables & Apparel,"Textiles, Apparel & Luxury Goods","Apparel, Accessories & Luxury Goods"
Consumer Discretionary,Consumer Durables & Apparel,"Textiles, Apparel & Luxury Goods",Textiles
Consumer Discretionary,Consumer Durables & Apparel,"Textiles, Apparel & Luxury Goods","Textiles, Apparel & Luxury Goods"
Consumer Discretionary,Consumer Services,Consumer Services,Consumer Services
Consumer Discretionary,Consumer Services,Diversified Consumer Services,Education Services
Consumer Discretionary,Consumer Services,Diversified Consumer Services,Specialized Consumer Services
Consumer Discretionary,Consumer Services,"Hotels, Restaurants & Leisure",Casinos & Gaming
Consumer Discretionary,Consumer Services,"Hotels, Restaurants & Leisure","Hotels, Restaurants & Leisure"
Consumer Discretionary,Consumer Services,"Hotels, Restaurants & Leisure",Leisure Facilities
Consumer Discretionary,Consumer Services,"Hotels, Restaurants & Leisure",Restaurants
Consumer Discretionary,Diversified Consumer Services,Education Services,Education
Consumer Discretionary,Diversified Consumer Services,Family Services,Family Services
Consumer Discretionary,Diversified Consumer Services,Specialized Consumer Services,Legal Services
Consumer Discretionary,Media,Media,Advertising
Consumer Discretionary,Media,Media,Broadcasting
Consumer Discretionary,Media,Media,Media
Consumer Discretionary,Media,Media,Movies & Entertainment
Consumer Discretionary,Media,Media,Public Relations
Consumer Discretionary,Media,Media,Publishing
Consumer Discretionary,Retailing,Distributors,Distributors
Consumer Discretionary,Retailing,Retailing,Retailing
Consumer Discretionary,Retailing,Specialty Retail,Home Improvement Retail
Consumer Discretionary,Retailing,Specialty Retail,Homefurnishing Retail
Consumer Discretionary,Retailing,Specialty Retail,Specialty Retail
Consumer Staples,Consumer Staples,Consumer Staples,Consumer Staples
Consumer Staples,Food & Staples Retailing,Food & Staples Retailing,Food Retail
Consumer Staples,"Food, Beverage & Tobacco",Beverages,Beverages
Consumer Staples,"Food, Beverage & Tobacco",Food Products,Agricultural Products
Consumer Staples,"Food, Beverage & Tobacco",Food Products,Food
Consumer Staples,"Food, Beverage & Tobacco",Food Products,Food Production
Consumer Staples,"Food, Beverage & Tobacco",Food Products,Packaged Foods & Meats
Consumer Staples,"Food, Beverage & Tobacco",Tobacco,Tobacco
Consumer Staples,Household & Personal Products,Personal Products,Cosmetics
Energy,Energy Equipment & Services,Gas Utilities,Oil & Gas
Financials,Banks,Banks,Banking & Mortgages
Financials,Diversified Financial Services,Diversified Financial Services,Accounting
Financials,Diversified Financial Services,Diversified Financial Services,Finance
Financials,Diversified Financial Services,Diversified Financial Services,Financial Services
Financials,Diversified Financials,Capital Markets,Asset Management & Custody Banks
Financials,Diversified Financials,Capital Markets,Diversified Capital Markets
Financials,Diversified Financials,Capital Markets,Fundraising
Financials,Diversified Financials,Capital Markets,Investment Banking & Brokerage
Financials,Diversified Financials,Diversified Financial Services,Payments
Financials,Insurance,Insurance,Insurance
Financials,Real Estate,Real Estate,Real Estate
Health Care,Health Care Equipment & Services,Health Care Equipment & Supplies,Eyewear
Health Care,Health Care Equipment & Services,Health Care Providers & Services,Health & Wellness
Health Care,Health Care Equipment & Services,Health Care Providers & Services,Health Care
Health Care,Health Care Equipment & Services,Health Care Providers & Services,Health Care Services
Health Care,"Pharmaceuticals, Biotechnology & Life Sciences",Biotechnology,Biotechnology
Health Care,"Pharmaceuticals, Biotechnology & Life Sciences",Life Sciences Tools & Services,Life Sciences Tools & Services
Health Care,"Pharmaceuticals, Biotechnology & Life Sciences",Pharmaceuticals,Pharmaceuticals
Industrials,Capital Goods,Aerospace & Defense,Aerospace & Defense
Industrials,Capital Goods,Capital Goods,Capital Goods
Industrials,Capital Goods,Commercial Services & Supplies,Commercial Printing
Industrials,Capital Goods,Construction & Engineering,Civil Engineering
Industrials,Capital Goods,Construction & Engineering,Construction
Industrials,Capital Goods,Construction & Engineering,Construction & Engineering
Industrials,Capital Goods,Construction & Engineering,Mechanical Engineering
Industrials,Capital Goods,Electrical Equipment,Electrical
Industrials,Capital Goods,Electrical Equipment,Electrical Equipment
Industrials,Capital Goods,Industrial Conglomerates,Industrials & Manufacturing
Industrials,Capital Goods,Machinery,Industrial Machinery
Industrials,Capital Goods,Machinery,Machinery
Industrials,Capital Goods,Trading Companies & Distributors,Trading Companies & Distributors
Industrials,Commercial & Professional Services,Commercial Services & Supplies,Business Supplies
Industrials,Commercial & Professional Services,Commercial Services & Supplies,Commercial Printing
Industrials,Commercial & Professional Services,Commercial Services & Supplies,Corporate & Business
Industrials,Commercial & Professional Services,Professional Services,Architecture
Industrials,Commercial & Professional Services,Professional Services,Automation
Industrials,Commercial & Professional Services,Professional Services,Consulting
Industrials,Commercial & Professional Services,Professional Services,Design
Industrials,Commercial & Professional Services,Professional Services,Human Resource & Employment Services
Industrials,Commercial & Professional Services,Professional Services,Professional Services
Industrials,Commercial & Professional Services,Professional Services,Research & Consulting Services
Industrials,Industrials,Industrials,Industrials
Industrials,Transportation,Air Freight & Logistics,Shipping & Logistics
Industrials,Transportation,Airlines,Airlines
Industrials,Transportation,Marine,Marine
Industrials,Transportation,Road & Rail,Ground Transportation
Industrials,Transportation,Transportation,Transportation
Information Technology,Semiconductors & Semiconductor Equipment,Semiconductors & Semiconductor Equipment,Semiconductors
Information Technology,Software & Services,Internet Software & Services,Cloud Services
Information Technology,Software & Services,Internet Software & Services,Internet
Information Technology,Software & Services,Internet Software & Services,Internet Software & Services
Information Technology,Software & Services,IT Services,Data Processing & Outsourced Services
Information Technology,Software & Services,Software,Graphic Design
Information Technology,Technology Hardware & Equipment,Communications Equipment,Communications
Information Technology,Technology Hardware & Equipment,Communications Equipment,Computer Networking
Information Technology,Technology Hardware & Equipment,"Electronic Equipment, Instruments & Components",Nanotechnology
Information Technology,Technology Hardware & Equipment,"Technology Hardware, Storage & Peripherals",Computer Hardware
Information Technology,Technology Hardware & Equipment,"Technology Hardware, Storage & Peripherals","Technology Hardware, Storage & Peripherals"
Materials,Construction Materials,Building Materials,Building Materials
Materials,Materials,Chemicals,Chemicals
Materials,Materials,Chemicals,Commodity Chemicals
Materials,Materials,Containers & Packaging,Containers & Packaging
Materials,Materials,Metals & Mining,Gold
Materials,Materials,Metals & Mining,Metals & Mining
Materials,Materials,Paper & Forest Products,Paper Products
Non for Profit,Non for Profit,Non for Profit,Non for Profit
Religious Organisations,Religious Organisations,Religious Organisations,Religious Organisations
Telecommunication Services,Telecommunication Services,Diversified Telecommunication Services,Integrated Telecommunication Services
Telecommunication Services,Telecommunication Services,Wireless Telecommunication Services,Wireless Telecommunication Services
Utilities,Independent Power and Renewable Electricity Producers,Renewable Electricity,Renewable Energy
Utilities,Utilities,Electric Utilities,Energy
Utilities,Utilities,Utilities,Utilities'
  end

  # includes keys for all sectors, industry groups and sub industries so can extract keys from company information and use same key for translation
  def self.industries
  {
    accounting: "Accounting",
    advertising: "Advertising",
    aerospace_defense: "Aerospace & Defense",
    agricultural_products: "Agricultural Products",
    air_freight_logistics: "Air Freight & Logistics",
    airlines: "Airlines",
    apparel_accessories_luxury_goods: "Apparel, Accessories & Luxury Goods",
    architecture: "Architecture",
    asset_management_custody_banks: "Asset Management & Custody Banks",
    automation: "Automation",
    automobiles_components: "Automobiles & Components",
    automotive: "Automotive",
    banking_mortgages: "Banking & Mortgages",
    banks: "Banks",
    beverages: "Beverages",
    biotechnology: "Biotechnology",
    broadcasting: "Broadcasting",
    building_materials: "Building Materials",
    business_supplies: "Business Supplies",
    capital_goods: "Capital Goods",
    casinos_gaming: "Casinos & Gaming",
    chemicals: "Chemicals",
    civil_engineering: "Civil Engineering",
    cloud_services: "Cloud Services",
    commercial_professional_services: "Commercial & Professional Services",
    commercial_printing: "Commercial Printing",
    commercial_services_supplies: "Commercial Services & Supplies",
    commodity_chemicals: "Commodity Chemicals",
    communications: "Communications",
    communications_equipment: "Communications Equipment",
    computer_hardware: "Computer Hardware",
    computer_networking: "Computer Networking",
    construction: "Construction",
    construction_engineering: "Construction & Engineering",
    construction_materials: "Construction Materials",
    consulting: "Consulting",
    consumer_discretionary: "Consumer Discretionary",
    consumer_durables_apparel: "Consumer Durables & Apparel",
    consumer_electronics: "Consumer Electronics",
    consumer_goods: "Consumer Goods",
    consumer_services: "Consumer Services",
    consumer_staples: "Consumer Staples",
    containers_packaging: "Containers & Packaging",
    corporate_business: "Corporate & Business",
    cosmetics: "Cosmetics",
    data_processing_outsourced_services: "Data Processing & Outsourced Services",
    design: "Design",
    distributors: "Distributors",
    diversified_capital_markets: "Diversified Capital Markets",
    diversified_consumer_services: "Diversified Consumer Services",
    diversified_financial_services: "Diversified Financial Services",
    diversified_financials: "Diversified Financials",
    diversified_support_services: "Diversified Support Services",
    diversified_telecommunication_services: "Diversified Telecommunication Services",
    education: "Education",
    education_services: "Education Services",
    electrical: "Electrical",
    electrical_equipment: "Electrical Equipment",
    electronic_equipment_instruments_components: "Electrionic Equipment Instruments & Components",
    electric_utilities: "Electric Utilities",
    energy: "Energy",
    energy_equipment_services: "Energy Equipment & Services",
    eyewear: "Eyewear",
    family_services: "Family Services",
    finance: "Finance",
    financial_services: "Financial Services",
    financials: "Financials",
    food: "Food",
    food_beverage_tobacco: "Food Beverage & Tobacco",
    food_staples_retailing: "Food & Staples Retailing",
    food_production: "Food Production",
    food_products: "Food Products",
    food_retail: "Food Retail",
    fundraising: "Fundraising",
    gas_utilities: "Gas Utilites",
    gold: "Gold",
    graphic_design: "Graphic Design",
    ground_transportation: "Ground Transportation",
    health_wellness: "Health & Wellness",
    health_care: "Health Care",
    health_care_equipment_services: "Health Care Equipment & Services",
    health_care_equipment_supplies: "Health Care Equipment & Supplies",
    health_care_providers_services: "Heath Care Providers & Services",
    health_care_services: "Health Care Services",
    home_improvement_retail: "Home Improvement Retail",
    homefurnishing_retail: "Homefurnishing Retail",
    hotels_restaurants_leisure: "Hotels, Restaurants & Leisure",
    household_personal_products: "Household & Personal Products",
    household_appliances: "Household Appliances",
    household_durables: "Household Durables",
    human_resource_employment_services: "Human Resource & Employment Services",
    independent_power_and_renewable_electricity_producers: "Independant Power & Renewable Electricity Producers",
    industrial_conglomerates: "Industrial Conglomerates",
    industrial_machinery: "Industrial Machinery",
    industrials: "Industrials",
    industrials_manufacturing: "Industrials & Manufacturing",
    information_technology: "Information Technology",
    insurance: "Insurance",
    integrated_telecommunication_services: "Integrated Telecommunication Services",
    internet: "Internet",
    internet_software_services: "Internet Software & Services",
    investment_banking_brokerage: "Investment Banking & Brokerage",
    it_services: "IT Services",
    legal_services: "Legal Services",
    leisure_facilities: "Leisure Facilities",
    leisure_products: "Leisure Prodcuts",
    life_sciences_tools_services: "Life Sciences Tools & Services",
    machinery: "Machinery",
    marine: "Marine",
    materials: "Materials",
    mechanical_engineering: "Mechanical Engineering",
    media: "Media",
    metals_mining: "Metals & Mining",
    movies_entertainment: "Movies & Entertainment",
    nanotechnology: "Nanotechnology",
    non_for_profit: "Non for Profit",
    oil_gas: "Oil & Gas",
    packaged_foods_meats: "Packaged Foods & Meats",
    paper_forest_products: "Paper & Forest Products",
    paper_products: "Paper Products",
    payments: "Payments",
    personal_products: "Personal Products",
    pharmaceuticals: "Pharmaceuticals",
    pharmaceuticals_biotechnology_life_sciences: "Pharmaceuticals Biotechnology & Life Sciences",
    photography: "Photography",
    professional_services: "Professional Services",
    public_relations: "Public Relations",
    publishing: "Publishing",
    real_estate: "Real Estate",
    religious_organisations: "Religious Organisations",
    renewable_electricity: "Rewnewable Electricity",
    renewable_energy: "Renewable Energy",
    research_consulting_services: "Research & Consulting Services",
    restaurants: "Restaurants",
    retailing: "Retailing",
    road_rail: "Road & Rail",
    semiconductors: "Semiconductors",
    semiconductors_semiconductor_equipment: "Semiconductors & Semiconductor Equipment",
    shipping_logistics: "Shipping & Logistics",
    software: "Software",
    software_services: "Software & Services",
    specialized_consumer_services: "Specialized Consumer Services",
    specialty_retail: "Specialty Retail",
    sporting_goods: "Sporting Goods",
    technology_hardware_storage_peripherals: "Technology Hardware, Storage & Peripherals",
    technology_hardware_equipment: "Technology Hardware & Equipment",
    telecommunication_services: "Telecommunication Services",
    textiles: "Textiles",
    textiles_apparel_luxury_goods: "Textiles, Apparel & Luxury Goods",
    tobacco: "Tobacco",
    trading_companies_distributors: "Trading Companies & Distributors",
    transportation: "Transportation",
    utilities: "Utilities",
    wireless_telecommunication_services: "Wireless Telecommunication Services"
  }
  end

  def cogs_percentage
    if rolling_12_month_cogs.to_f != 0.0
      rolling_12_month_cogs * 100
    else
      0
    end
  end

  def primary_contact
    contacts.where("id = ? OR (platform_id = ? AND platform_id IS NOT NULL)", primary_contact_id, source_contact_id.to_s).where.not(deleted: true).where.not(temp: true).first
  end

  #TODO @command
  def do_propagate_sales_reps
    if propagate_sales_reps
      Contact.unscoped.where(company_id: id).where("sales_rep_platform_id IS DISTINCT FROM ?", sales_rep.try(:platform_id)).update_all(sales_rep_platform_id: sales_rep.try(:platform_id), sales_rep_user_id: sales_rep.try(:user_id))
      if Platform.is_mbe?(self)
        Invoice.unscoped.where(company_id: id).where("sales_rep_platform_id IS DISTINCT FROM ?", sales_rep.try(:platform_id)).update_all(sales_rep_platform_id: sales_rep.try(:platform_id), sales_rep_user_id: sales_rep.try(:user_id))
        Shipment.unscoped.where(company_id: id).where("sales_rep_platform_id IS DISTINCT FROM ?", sales_rep.try(:platform_id)).update_all(sales_rep_platform_id: sales_rep.try(:platform_id), sales_rep_user_id: sales_rep.try(:user_id))
      end
    end
  end

  def has_sub_account?(target_company)
    target_company.present? && !account_display_id.blank? && account_display_id != "0" && target_company.master_account == account_display_id
  end
end
