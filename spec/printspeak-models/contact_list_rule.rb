class ContactListRule < ActiveRecord::Base
  belongs_to :contact_list
  belongs_to :taken_by
  # belongs_to :sales_rep # conflict with private method

  attr_accessor :date_format

  validate do |rule|
    if rule.contact_list.global
      rule.sales_rep_id = nil
      rule.taken_by_id = nil
    end

    if ContactListRule.get_type(rule.category).nil? && ContactListRule.get_modifiers(rule.category).nil?
      rule.errors[:base] << "Invalid Category."
    else

      if ContactListRule.exists?(contact_list_id: rule.contact_list.id, category: rule.category, operand: rule.operand, value: rule.value, value2: rule.value2, modifier: rule.modifier, modifier_operand: rule.modifier_operand, modifier_value: rule.modifier_value, modifier_value2: rule.modifier_value2, modifier2: rule.modifier2, modifier2_operand: rule.modifier2_operand, modifier2_value: rule.modifier2_value, modifier2_value2: rule.modifier2_value2, negate: rule.negate, sales_rep_id: rule.sales_rep_id, taken_by_id: rule.taken_by_id)
        rule.errors[:base] << "This rule already exists."
      end

      if !ContactListRule.get_type(rule.category).nil?
        if rule.logical_operand == "unknown"
          rule.errors[:base] << "Invalid Operand."
        else
          case ContactListRule.get_type(rule.category)
          when "numeric"
            rule.errors[:base] << "Value must be numeric." unless numeric_validate?(rule.value)
            if rule.operand == "between"
              rule.errors[:base] << "Value2 must be numeric." unless numeric_validate?(rule.value2)
            end
          when "inverted_numeric"
            rule.errors[:base] << "Value must be numeric." unless numeric_validate?(rule.value)
            if rule.operand == "between"
              rule.errors[:base] << "Value2 must be numeric." unless numeric_validate?(rule.value2)
            end
          when "integer"
            rule.errors[:base] << "Value must be an integer." unless integer_validate?(rule.value)
            if rule.operand == "between"
              rule.errors[:base] << "Value2 must be an integer." unless integer_validate?(rule.value2)
            end
          when "inverted_integer"
            rule.errors[:base] << "Value must be an integer." unless integer_validate?(rule.value)
            if rule.operand == "between"
              rule.errors[:base] << "Value2 must be an integer." unless integer_validate?(rule.value2)
            end
          when "existence"
            rule.value = ""
            rule.value2 = ""
          when "boolean"
            rule.value = ""
            rule.value2 = ""
          when "value"
            case rule.category
            when "company_status"
              rule.errors[:base] << "Invalid value." unless ContactListRule.company_status.any? { |possible_value| possible_value[1] == value }
            when "lead_stage"
              if value != "any"
                lead_stage = ProspectStatus.where(id: value).first
                rule.errors[:base] << "Invalid lead stage." unless lead_stage
              end
            when "lead_type"
              lead_type = LeadType.where(id: value).first
              rule.errors[:base] << "Invalid lead type." unless lead_type
            when "privacy"
              if !rule.contact_list.enterprise.privacy_types.include?(value)
                rule.errors[:base] << "Invalid privacy option."
              end
            else
              rule.errors[:base] << "Unhandled value validation."
            end
          when "match"
            rule.errors[:base] << "Invalid value." if rule.value.blank?
            rule.value2 = ""
          when "tag"
            tag_category = TagCategory.unscoped.where(id: rule.value).first
            rule.errors[:base] << "Invalid Tag." if tag_category.nil?
            rule.value2 = ""
          when "campaign"
            campaign = Campaign.unscoped.where(id: rule.value).first
            rule.errors[:base] << "Invalid Campaign." if campaign.nil?
            if rule.value2.blank?
              rule.value2 = ""
            elsif %w[opened not_opened].include?(rule.value2)
              # Do nothing
            else
              rule.errors[:base] << "Invalid Campaign send status." if campaign.nil?
            end

          when "date"
            rule.errors[:base] << "Date is invalid." unless date_validate?(rule.value, rule.date_format)
            if rule.operand == "between"
              rule.errors[:base] << "Second date is invalid." unless date_validate?(rule.value2, rule.date_format)
            end
          when "relative_date"
            rule.errors[:base] << "Date must be a relative date. (Such as '3 days ago')" unless date_relative_validate?(rule.value)
            if rule.operand == "between"
              rule.errors[:base] << "Second date must be a relative date. (Such as '3 days ago')." unless date_relative_validate?(rule.value2)
            end
          when "quarter"
            rule.errors[:base] << "Date must be a quarter." unless quarter_validate?(rule.value)
            if rule.operand == "between"
              rule.errors[:base] << "Second date must be a quarter." unless quarter_validate?(rule.value2)
            end
          when "sales_rep"
            if contact_list.tenant.sales_rep_for_locations
              location = Location.where(id: sales_rep_id).first
              rule.errors[:base] << "Invalid Location." if location.nil?
            else
              sales_rep = User.where(id: sales_rep_id).first
              rule.errors[:base] << "Invalid Sales Rep." if sales_rep.nil?
            end
          when "estimates_status"
            rule.value = ""
            rule.value2 = ""
          when "industry"
            valid = false
            industries = rule.value.try(:split, ",") || []
            if industries.count > 0
              valid = (industries - Company.sub_industries_hash.map { |item| item["name"] }).empty?
            end
            rule.value2 = ""
            rule.errors[:base] << "Invalid Industry" if !valid
          else
            rule.errors[:base] << "Unhandled validation."
          end
        end
      end

      if !rule.modifier.blank?
        errors = rule.valid_modifier?(1)
        rule.errors[:base].concat(errors) if errors.count > 0
      end

      if !rule.modifier2.blank?
        errors = rule.valid_modifier?(2)
        rule.errors[:base].concat(errors) if errors.count > 0
      end

    end
  end

  def valid_modifier?(use_modifier = 1)
    errors = []
    current_modifier = modifier
    current_modifier_operand = modifier_operand
    current_modifier_value = modifier_value
    current_modifier_value2 = modifier_value2
    if use_modifier == 2
      current_modifier = modifier2
      current_modifier_operand = modifier2_operand
      current_modifier_value = modifier2_value
      current_modifier_value2 = modifier2_value2
    end
    if !ContactListRule.get_modifiers(category, use_modifier).include?(current_modifier)
      errors << "Invalid Modifier."
    else
      if logical_operand(use_modifier) == "unknown"
        errors << "Invalid Modifier Operand."
      else
        case current_modifier
        when "date"
          errors << "Date is invalid." unless date_validate?(current_modifier_value, date_format)
          if current_modifier_operand == "between"
            errors << "Second date is invalid." unless date_validate?(current_modifier_value2, date_format)
          end
        when "relative_date"
          errors << "Date must be a relative date. (Such as '3 days ago')" unless date_relative_validate?(current_modifier_value)
          if current_modifier_operand == "between"
            errors << "Second date must be a relative date. (Such as '3 days ago')." unless date_relative_validate?(current_modifier_value2)
          end
        when "quarter"
          errors << "Date must be a quarter." unless quarter_validate?(current_modifier_value)
          if current_modifier_operand == "between"
            errors << "Second date must be a quarter." unless quarter_validate?(current_modifier_value2)
          end
        when "estimates_status"
        else
          errors << "Unhandled validation."
        end
      end
    end
    errors
  end

  def self.categories_for_dropdown(target_tenant, list)
    result = []

    ContactListRule.categories.each do |category, data|
      next if list.global && data[:hide_when_global]
      next if !data[:platform].nil? && !data[:platform].include?(target_tenant.enterprise.platform_type)

      name = I18n.t_prefix(category, target_tenant)
      if target_tenant.sales_rep_for_locations && category == "sales_rep"
        name = I18n.t("location")
      end
      result << [name, category]
    end
    result
  end

  def self.categories
    {
      "total_sales" => {primary: "numeric", modifiers: %w[date relative_date quarter]},
      "web_sales" => {primary: "numeric", modifiers: %w[date relative_date quarter]},
      "single_sale" => {primary: "numeric", modifiers: %w[date relative_date quarter]},
      "single_estimate" => {primary: "numeric", platform: ["printsmith"], modifiers: %w[date relative_date quarter], modifiers2: ["estimates_status"]},
      "sales_per_month" => {primary: "integer", modifiers: %w[date relative_date quarter]},
      "sales_per_month_by_company" => {primary: "integer", modifiers: %w[date relative_date quarter]},
      "contact_created_date" => {modifiers: %w[date relative_date quarter]},
      "company_created_date" => {modifiers: %w[date relative_date quarter]},
      "last_pickup_date" => {platform: ["printsmith"], modifiers: %w[date relative_date quarter]},
      "last_order_date" => {platform: ["printsmith"], modifiers: %w[date relative_date quarter]},
      "first_order_date" => {platform: ["printsmith"], modifiers: %w[date relative_date quarter]},
      "first_sale_date" => {modifiers: %w[date relative_date quarter]},
      "first_estimate_date" => {platform: ["printsmith"], modifiers: %w[date relative_date quarter]},
      "last_estimate_date" => {platform: ["printsmith"], modifiers: %w[date relative_date quarter]},
      "email_address" => {direct: true, primary: "existence"},
      "phone_number" => {direct: true, primary: "existence"},
      "walk_in" => {direct: true, primary: "boolean"},
      "prospect" => {direct: true, primary: "boolean"},
      "statement_contact" => {direct: true, primary: "boolean", platform: ["printsmith"]},
      "invoice_contact" => {direct: true, primary: "boolean"},
      "company_status" => {direct: true, platform: ["printsmith"], primary: "value"},
      "buy_frequency" => {direct: true, primary: "numeric"},
      "orders_in_progress" => {platform: ["printsmith"] , primary: "boolean"},
      "address" => {direct: true, primary: "existence"},
      "company_ranking" => {direct: true, primary: "numeric"},
      "contact_ranking" => {direct: true, primary: "inverted_numeric"},
      "tag_match" => {direct: true, primary: "tag"},
      "sent_campaign" => {primary: "campaign", modifiers: %w[date relative_date quarter]},
      "first_name" => {direct: true, primary: "existence"},
      "estimates_in_progress" => {primary: "boolean", platform: ["printsmith"]},
      "estimates_status" => {primary: "estimates_status", platform: ["printsmith"], modifiers: %w[date relative_date quarter]},
      "contact_growth" => {direct: true, primary: "numeric"},
      "company_growth" => {direct: true, primary: "numeric"},
      "average_invoice" => {direct: true, primary: "numeric"},
      "sales_rep" => {direct: true, hide_when_global: true, primary: "sales_rep"},
      "days_since_single_sale" => {primary: "numeric"},
      "industry" => {primary: "industry"},
      "estimate_ordered_date" => {platform: ["printsmith"], modifiers: %w[date relative_date quarter]},
      "invoice_ordered_date" => {platform: ["printsmith"], modifiers: %w[date relative_date quarter]},
      "lead_stage" => {primary: "value"},
      "lead_type" => {direct: true, primary: "value"},
      "days_since_last_pickup_date" => {primary: "numeric", platform: ["printsmith"]},
      "days_since_last_sale_date" => {platform: ["mbe"], primary: "numeric"},
      "first_shipment_date" => {platform: ["mbe"], modifiers: %w[date relative_date quarter]},
      "last_shipment_date" => {platform: ["mbe"], modifiers: %w[date relative_date quarter]},
      "last_sale_date" => {platform: ["mbe"], modifiers: %w[date relative_date quarter]},
      "privacy" => {direct: true, primary: "value", platform: ["mbe"]}
    }
  end

  def self.numeric_operands
    {
      "greater_than" => ">",
      "equal_to_or_greater_than" => ">=",
      "less_than" => "<",
      "equal_to_or_less_than" => "<=",
      "equal_to" => "=",
      "between" => ".."
    }
  end

  def self.inverted_numeric_operands
    {
      "greater_than" => "<",
      "equal_to_or_greater_than" => "<=",
      "less_than" => ">",
      "equal_to_or_less_than" => ">=",
      "equal_to" => "=",
      "between" => ".."
    }
  end

  def self.integer_operands
    {
      "greater_than" => ">",
      "equal_to_or_greater_than" => ">=",
      "less_than" => "<",
      "equal_to_or_less_than" => "<=",
      "equal_to" => "=",
      "between" => ".."
    }
  end

  def self.inverted_integer_operands
    {
      "greater_than" => "<",
      "equal_to_or_greater_than" => "<=",
      "less_than" => ">",
      "equal_to_or_less_than" => ">=",
      "equal_to" => "=",
      "between" => ".."
    }
  end

  def self.date_operands
    {
      "before" => "<",
      "after" => ">",
      "on" => "=",
      "between" => ".."
    }
  end

  def self.relative_date_operands
    {
      "before" => "<",
      "after" => ">",
      "on" => "=",
      "between" => ".."
    }
  end

  def self.quarter_operands
    {
      "before" => "<",
      "after" => ">",
      "during" => "=",
      "between" => ".."
    }
  end

  def self.existence_operands
    {
      "exists" => "IS NOT NULL",
      "not_exists" => "IS NULL"
    }
  end

  def self.boolean_operands
    {
      "true" => true,
      "false" => false
    }
  end

  def self.value_operands
    {
      "is" => "=",
      "is_not" => "!="
    }
  end

  def self.match_operands
    {
      "matches" => "ILIKE",
      "does_not_match" => "NOT ILIKE"
    }
  end

  def self.tag_operands
    {
      "matches" => "=",
      "does_not_match" => "!="
    }
  end

  def self.campaign_operands
    {
      "sent" => "="
    }
  end

  def self.sales_rep_operands
    {
      "is" => "=",
      "is_not" => "!="
    }
  end

  def self.estimates_status_operands
    {
      "won" => "Won",
      "neutral" => "Neutral",
      "lost" => "Lost",
      "any" => ""
    }
  end

  def self.industry_operands
    {
      "is" => "="
    }
  end

  def self.quarters
    [
      ["This Quarter", "this_quarter"],
      ["Last Quarter", "last_quarter"],
      ["First Quarter", "quarter_1"],
      ["Second Quarter", "quarter_2"],
      ["Third Quarter", "quarter_3"],
      ["Fourth Quarter", "quarter_4"],
      ["First Quarter Last Year", "quarter_1_last_year"],
      ["Second Quarter Last Year", "quarter_2_last_year"],
      ["Third Quarter Last Year", "quarter_3_last_year"],
      ["Fourth Quarter Last Year", "quarter_4_last_year"]
    ]
  end

  def self.company_status
    [
      %w[Delinquent CustomerStatusDelinquent],
      %w[Inactive CustomerStatusInactive],
      ["Past Due", "CustomerStatusPastDue"],
      %w[Frozen CustomerStatusFrozen],
      %w[New CustomerStatusNew],
      %w[Current CustomerStatusCurrent]
    ]
  end

  def get_sql(tenant)
    category_method = method(category.to_sym) if respond_to?(category.to_sym, true)
    if category_method
      # category_method.call(tenant).select("contacts.id").marketing(tenant).group("contacts.id").to_sql
      sql = category_method.call(tenant)
      return "" if sql.blank?
      if ContactListRule.is_direct?(category)
        expression = negate? ? "NOT" : ""
        sql = " AND #{expression} (#{sql})"
      else
        expression = negate? ? "NOT EXISTS" : "EXISTS"
        sql = " AND #{expression}(#{sql})"
      end
    end
    sql
  end

  def get_rule_text(tenant)
    result = "unknown"
    method_name = "#{category}_text"
    category_text_method = method(method_name.to_sym) if respond_to?(method_name.to_sym, true)
    if category_text_method
      result = category_text_method.call(tenant)
    end
    result.html_safe
  end

  def get_mbe_rule_text(tenant)
    result = []
    result << negate_text(I18n.t("exclude").upcase) if negate

    if !operand.blank?
      op_text = I18n.t("#{operand}")
      value_t = resolve_value if %w[sent_campaign tag_match lead_stage lead_type privacy industry].include?(category) && !value.blank?
      op_value_text = ": #{value_t ? value_t : value}" if !value.blank?
      op_value_text += " & #{value2}" if operand == "between"

      result << "<b>#{op_text}</b>#{op_value_text}"
    end

    if !modifier.blank?
      mod_text = modifier == "date" ? I18n.t("date.word") : I18n.t("#{modifier}")
      if %w[sales_per_month sales_per_month_by_company].include?(category)
        mod_op_text = I18n.t("between")
        mod_value_text = per_month_text(tenant)
      else
        mod_op_text = I18n.t("#{modifier_operand}")
        mod_value_text = modifier == "quarter" ? " #{I18n.t("#{modifier_value}")}" : " #{modifier_value}"
        mod_value_text += modifier == "quarter" ? " & #{I18n.t("#{modifier_value2}")}" : " & #{modifier_value2}" if !modifier_value2.blank?
      end

      result << "<b>#{mod_text}</b>: #{mod_op_text} #{mod_value_text}"
    end

    if !sales_rep_id.blank?
      rep_name = User.find_by(id: sales_rep_id).full_name
      result << "<b>#{I18n.t("platform.sales_rep", mbe: true)}:</b> #{rep_name}"
    end

    result.join(", ").html_safe
  end

  def per_month_text(tenant)
    date1, date2 = get_modifier_dates(tenant)
    start_date, end_date = set_month_range(date1, date2)
    start_month = I18n.l(start_date, format: "%B %Y")
    end_month = I18n.l(end_date, format: "%B %Y")
    " #{start_month} & #{end_month}"
  end

  def resolve_value
    case category
    when "sent_campaign"
      result = Campaign.unscoped.where(id: value).first.try(:name)
    when "tag_match"
      result = TagCategory.unscoped.where(id: value).first.try(:name)
    when "lead_stage"
      result = value == "any" ? I18n.t("any") : ProspectStatus.where(id: value).first.try(:name)
    when "lead_type"
      result = LeadType.where(id: value).first.try(:name)
    when "privacy"
      result = I18n.t("privacy.#{value}")
    when "industry"
      result = []
      industries = value.split(",")
      industries.each do |industry|
        result << I18n.t("industries.#{Company.industries.key(industry)}")
      end
      result = result.join(",")
    end
    result
  end

  def set_month_range(date1, date2)
    if date1.nil?
      date1 = DateTime.now
      date2 = DateTime.now - 1.year
    end

    if date2.nil?
      if modifier_operand == "on"
        date2 = date1
      elsif modifier_operand == "before"
        date2 = date1 - 1.year
      else
        date2 = DateTime.now
      end
    end

    start_date = date1.beginning_of_month
    end_date = date2.end_of_month
    if start_date > end_date
      start_date = date2.beginning_of_month
      end_date = date1.end_of_month
    end
    [start_date, end_date]
  end

  def get_rule_contextuals(tenant, contacts)
    result = {}
    method_name = "#{category}_contextuals"
    category_contextuals_method = method(method_name.to_sym) if respond_to?(method_name.to_sym, true)
    if category_contextuals_method
      result = category_contextuals_method.call(tenant, contacts)
    end
    result
  end

  def contacts(tenant, page = nil, per = nil)
    query = contacts_query(tenant, page, per)
    if query.blank?
      result = Contact.none
      total_count = 0
    else
      result = Contact.find_by_sql(query)
      total_count = result.first.try(:total_count) || 0
    end
    Kaminari.paginate_array(result, total_count: total_count).page(page).per(per)
  end

  def contacts_query(tenant, page = nil, per = nil)
    page ||= 1
    per ||= 10
    offset = (page.to_i - 1) * per

    rule_condition = get_sql(tenant)

    if !rule_condition.blank?
      limit = "LIMIT #{per} OFFSET #{offset}" unless page.to_i <= 0
      query = %Q{
        SELECT contacts.*, (COUNT(*) OVER()) AS total_count
        FROM contacts
        LEFT OUTER JOIN companies ON companies.id = contacts.company_id
        WHERE contacts.tenant_id = #{tenant.id}
        #{contact_list.account_type_query}
        AND contacts.deleted = false
        AND contacts.unsubscribed = false
        AND companies.marketing_do_not_mail = false
        AND NOT EXISTS ( SELECT null FROM email_soft_bounces WHERE email_soft_bounces.tenant_id = #{tenant.id} AND LOWER(BTRIM(contacts.email)) = email_soft_bounces.email_address AND soft_bounce_count >= 3 )
        #{rule_condition}
        ORDER BY contacts.id DESC NULLS LAST
        #{limit}
      }
    end

    query
  end

  def self.is_direct?(category)
    result = ContactListRule.categories[category.to_s][:direct] if ContactListRule.categories.has_key?(category.to_s)
    result.nil? ? false : result
  end

  def self.get_type(category)
    result = ContactListRule.categories[category.to_s][:primary] if ContactListRule.categories.has_key?(category.to_s)
    result
  end

  def self.get_modifiers(category, use_modifier = 1)
    result = ContactListRule.categories[category.to_s][:modifiers] if ContactListRule.categories.has_key?(category.to_s)
    if use_modifier == 2
      result = ContactListRule.categories[category.to_s][:modifiers2] if ContactListRule.categories.has_key?(category.to_s)
    end
    result = [] if result.nil?
    result
  end

  def logical_operand(use_modifier = 0)
    result = "unknown"
    target = operand
    type = ContactListRule.get_type(category)
    case use_modifier
    when 1
      target = modifier_operand
      type = modifier
    when 2
      target = modifier2_operand
      type = modifier2
    end
    method_name = "#{type}_operands"
    operands_method = ContactListRule.method(method_name) if ContactListRule.respond_to?(method_name, true)
    if operands_method
      operands = operands_method.call
      result = operands[target.to_s] if operands.has_key?(target.to_s)
    end
    result
  end

  def logical_operand_name(use_modifier = 0)
    result = "unknown"
    target = operand
    type = ContactListRule.get_type(category)
    case use_modifier
    when 1
      target = modifier_operand
      type = modifier
    when 2
      target = modifier2_operand
      type = modifier2
    end
    method_name = "#{type}_operands"
    operands_method = ContactListRule.method(method_name) if ContactListRule.respond_to?(method_name, true)
    if operands_method
      operands = operands_method.call
      result = target.to_s if operands.has_key?(target.to_s)
    end
    result
  end

  private

  def numeric_validate?(value)
    begin
      Float(value)
      true
    rescue StandardError
      false
    end
  end

  def integer_validate?(value)
    begin
      Integer(value)
      true
    rescue StandardError
      false
    end
  end

  def date_validate?(value, date_format)
    result = false
    begin
      parsed_date = Date.strptime(value, date_format)
      result = true if parsed_date.year >= 0 && parsed_date.year < 10000
    rescue StandardError
    end
    result
  end

  def date_relative_validate?(value)
    result = false
    begin
      parsed_date = Chronic.parse(value)
      result = true if !parsed_date.nil? && parsed_date.year >= 0 && parsed_date.year < 10000
    rescue StandardError
    end
    result
  end

  def quarter_validate?(value)
    valid = false
    ContactListRule.quarters.each do |quarter|
      if quarter[1] == value
        valid = true
        break
      end
    end
    valid
  end

  def parse_quarter(quarter)
    case quarter
    when "this_quarter"
      {start_time: Time.now.beginning_of_quarter, end_time: Time.now.end_of_quarter}
    when "last_quarter"
      {start_time: 3.months.ago.beginning_of_quarter, end_time: 3.months.ago.end_of_quarter}
    when "quarter_1"
      {start_time: Time.parse("January 1"), end_time: Time.parse("January 1").end_of_quarter}
    when "quarter_2"
      {start_time: Time.parse("April 1"), end_time: Time.parse("April 1").end_of_quarter}
    when "quarter_3"
      {start_time: Time.parse("July 1"), end_time: Time.parse("July 1").end_of_quarter}
    when "quarter_4"
      {start_time: Time.parse("October 1"), end_time: Time.parse("October 1").end_of_quarter}
    when "quarter_1_last_year"
      {start_time: Time.parse("January 1 #{Time.now.year - 1}"), end_time: Time.parse("January 1 #{Time.now.year - 1}").end_of_quarter}
    when "quarter_2_last_year"
      {start_time: Time.parse("April 1 #{Time.now.year - 1}"), end_time: Time.parse("April 1 #{Time.now.year - 1}").end_of_quarter}
    when "quarter_3_last_year"
      {start_time: Time.parse("July 1 #{Time.now.year - 1}"), end_time: Time.parse("July 1 #{Time.now.year - 1}").end_of_quarter}
    when "quarter_4_last_year"
      {start_time: Time.parse("October 1 #{Time.now.year - 1}"), end_time: Time.parse("October 1 #{Time.now.year - 1}").end_of_quarter}
    end
  end

  def get_modifier_dates(tenant, use_modifier = 1)
    current_modifier = modifier
    current_modifier_operand = modifier_operand
    current_modifier_value = modifier_value
    current_modifier_value2 = modifier_value2
    if use_modifier == 2
      current_modifier = modifier2
      current_modifier_operand = modifier2_operand
      current_modifier_value = modifier2_value
      current_modifier_value2 = modifier2_value2
    end

    date1 = nil
    date2 = nil
    case current_modifier
    when "date"
      date1 = Date.strptime(current_modifier_value, contact_list.tenant.date_format).try(:in_time_zone, tenant.time_zone)
      date2 = Date.strptime(current_modifier_value2, contact_list.tenant.date_format).try(:in_time_zone, tenant.time_zone) if current_modifier_operand == "between"
    when "relative_date"
      date1 = Chronic.parse(current_modifier_value).try(:in_time_zone, tenant.time_zone)
      date2 = Chronic.parse(current_modifier_value2).try(:in_time_zone, tenant.time_zone) if current_modifier_operand == "between"
    when "quarter"
      date1 = parse_quarter(current_modifier_value)[:start_time].try(:in_time_zone, tenant.time_zone)
      date2 = parse_quarter(current_modifier_value)[:end_time].try(:in_time_zone, tenant.time_zone) if current_modifier_operand == "during"
      date2 = parse_quarter(current_modifier_value2)[:end_time].try(:in_time_zone, tenant.time_zone) if current_modifier_operand == "between"
    end
    [date1, date2]
  end

  def negate_text(text)
    "<span style=\"color:#ff0000\"><b>#{text}</b></span>"
  end

  def total_sales(tenant)
    if logical_operand_name == "between"
      primary_condition = "HAVING SUM(invoices.grand_total) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value)} AND #{ActiveRecord::Base::sanitize(value2)}"
    else
      primary_condition = "HAVING SUM(invoices.grand_total) #{logical_operand} #{ActiveRecord::Base::sanitize(value)}"
    end

    if !modifier.blank?
      date1, date2 = get_modifier_dates(tenant)
      if !date1.nil? && !date2.nil?
        modifier_condition = "AND invoices.pickup_date BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
      elsif !date1.nil?
        modifier_condition = "AND invoices.pickup_date #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
      end
    end

    if !sales_rep_id.blank?
      sales_rep_condition = "AND (contacts.sales_rep_user_id = #{sales_rep_id} OR companies.sales_rep_user_id = #{sales_rep_id} OR invoices.sales_rep_user_id = #{sales_rep_id})"
    end
    if !taken_by_id.blank?
      taken_by_condition = "AND (invoices.taken_by_user_id = #{taken_by_id})"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      AND invoices.voided = false
      AND invoices.deleted = false
      #{"AND #{Invoice.INVOICED}" if Platform.is_mbe?(tenant)}
      #{modifier_condition}
      #{sales_rep_condition}
      #{taken_by_condition}
      #{primary_condition}
    }
  end

  def total_sales_text(tenant)
    negate_text = "#{negate_text("Does not")} have " if negate
    between_value = " and #{value2}" if logical_operand_name == "between"
    result = "#{negate_text}#{logical_operand_name.humanize(capitalize: negate ? false : true)} #{value}#{between_value} in sales"
    if !modifier.blank?
      result = "#{result} #{modifier_operand} #{modifier_value}"
      result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    end
    if !sales_rep_id.blank?
      sales_rep = User.find(sales_rep_id)
      result = "#{result} - Sales Rep: #{sales_rep.full_name}"
    end
    if !taken_by_id.blank?
      taken_by = User.find(taken_by_id)
      result = "#{result} - Taken By: #{taken_by.full_name}"
    end
    result
  end

  def web_sales(tenant)
    if logical_operand_name == "between"
      primary_condition = "HAVING SUM(invoices.grand_total) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value)} AND #{ActiveRecord::Base::sanitize(value2)}"
    else
      primary_condition = "HAVING SUM(invoices.grand_total) #{logical_operand} #{ActiveRecord::Base::sanitize(value)}"
    end

    if !modifier.blank?
      date1, date2 = get_modifier_dates(tenant)
      if !date1.nil? && !date2.nil?
        modifier_condition = "AND invoices.pickup_date BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
      elsif !date1.nil?
        modifier_condition = "AND invoices.pickup_date #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
      end
    end

    if !sales_rep_id.blank?
      sales_rep_condition = "AND (contacts.sales_rep_user_id = #{sales_rep_id} OR companies.sales_rep_user_id = #{sales_rep_id} OR invoices.sales_rep_user_id = #{sales_rep_id})"
    end
    if !taken_by_id.blank?
      taken_by_condition = "AND (invoices.taken_by_user_id = #{taken_by_id})"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      #{"AND #{Invoice.INVOICED}" if Platform.is_mbe?(tenant)}
      AND invoices.voided = false
      AND invoices.deleted = false
      AND invoices.web = true
      #{modifier_condition}
      #{sales_rep_condition}
      #{taken_by_condition}
      #{primary_condition}
    }
  end

  def web_sales_text(tenant)
    negate_text = "#{negate_text("Does not")} have " if negate
    between_value = " and #{value2}" if logical_operand_name == "between"
    result = "#{negate_text}#{logical_operand_name.humanize(capitalize: negate ? false : true)} #{value}#{between_value} in web sales"
    if !modifier.blank?
      result = "#{result} #{modifier_operand} #{modifier_value}"
      result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    end
    if !sales_rep_id.blank?
      sales_rep = User.find(sales_rep_id)
      result = "#{result} - Sales Rep: #{sales_rep.full_name}"
    end
    if !taken_by_id.blank?
      taken_by = User.find(taken_by_id)
      result = "#{result} - Taken By: #{taken_by.full_name}"
    end
    result
  end

  def single_sale(tenant)
    if logical_operand_name == "between"
      primary_condition = "AND invoices.grand_total BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value)} AND #{ActiveRecord::Base::sanitize(value2)}"
    else
      primary_condition = "AND invoices.grand_total #{logical_operand} #{ActiveRecord::Base::sanitize(value)}"
    end

    if !modifier.blank?
      date1, date2 = get_modifier_dates(tenant)
      if !date1.nil? && !date2.nil?
        modifier_condition = "AND invoices.pickup_date BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
      elsif !date1.nil?
        modifier_condition = "AND invoices.pickup_date #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
      end
    end

    if !sales_rep_id.blank?
      sales_rep_condition = "AND (contacts.sales_rep_user_id = #{sales_rep_id} OR companies.sales_rep_user_id = #{sales_rep_id} OR invoices.sales_rep_user_id = #{sales_rep_id})"
    end
    if !taken_by_id.blank?
      taken_by_condition = "AND (invoices.taken_by_user_id = #{taken_by_id})"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      #{"AND #{Invoice.INVOICED}" if Platform.is_mbe?(tenant)}
      AND invoices.voided = false
      AND invoices.deleted = false
      AND invoices.pickup_date IS NOT NULL
      #{modifier_condition}
      #{sales_rep_condition}
      #{taken_by_condition}
      #{primary_condition}
    }
  end

  def single_sale_contextuals(tenant, contacts)
    result = {}
    sales = Sale.joins(:contact).where(contact_id: contacts.map { |contact| contact.id }).order(created_at: :asc)
    if logical_operand_name == "between"
      sales = sales.where("((invoices.grand_total >= ? AND invoices.grand_total <= ?) OR (invoices.grand_total <= ? AND invoices.grand_total >= ?))", value, value2, value, value2)
    else
      sales = sales.where("invoices.grand_total #{logical_operand} ?", value)
    end
    if !modifier.blank?
      date1, date2 = get_modifier_dates(tenant)
      if !date1.nil? && !date2.nil?
        sales = sales.where("((invoices.pickup_date >= ? AND invoices.pickup_date <= ?) OR (invoices.pickup_date <= ? AND invoices.pickup_date >= ?))", date1, date2, date1, date2)
      elsif !date1.nil?
        sales = sales.where("invoices.pickup_date #{logical_operand(1)} ?", date1)
      end
    end
    if !sales_rep_id.blank?
      sales = sales.joins("INNER JOIN sales_reps ON sales_reps.platform_id = invoices.sales_rep_platform_id").where(sales_reps: {user_id: sales_rep_id})
    end
    contacts.each do |contact|
      invoice_numbers = []
      invoice_totals = []
      sales.each do |sale|
        if sale.contact_id == contact.id
          invoice_numbers << sale.invoice_number
          invoice_totals << sale.grand_total
        end
      end
      result[contact.id] = {invoice_numbers: invoice_numbers, invoice_totals: invoice_totals}
    end
    result
  end

  def single_sale_text(tenant)
    negate_text = "#{negate_text("Does not")} have a " if negate
    between_value = " and #{value2}" if logical_operand_name == "between"
    result = "#{negate_text}#{"single".humanize(capitalize: negate ? false : true)} sale #{logical_operand_name.humanize(capitalize: false)} #{value}#{between_value}"
    if !modifier.blank?
      result = "#{result} #{modifier_operand} #{modifier_value}"
      result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    end
    if !sales_rep_id.blank?
      sales_rep = User.find(sales_rep_id)
      result = "#{result} - Sales Rep: #{sales_rep.full_name}"
    end
    if !taken_by_id.blank?
      taken_by = User.find(taken_by_id)
      result = "#{result} - Taken By: #{taken_by.full_name}"
    end
    result
  end

  def single_estimate(tenant)
    primary_condition = ""
    if logical_operand_name == "between"
      primary_condition = "AND estimates.grand_total BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value)} AND #{ActiveRecord::Base::sanitize(value2)}"
    else
      primary_condition = "AND estimates.grand_total #{logical_operand} #{ActiveRecord::Base::sanitize(value)}"
    end

    modifier_condition = ""
    if !modifier.blank?
      date1, date2 = get_modifier_dates(tenant)
      if !date1.nil? && !date2.nil?
        modifier_condition = "AND estimates.ordered_date BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
      elsif !date1.nil?
        modifier_condition = "AND estimates.ordered_date #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
      end
    end

    modifier2_condition = ""
    if !modifier2.blank?
      modifier2_condition = "AND estimates.status = '#{logical_operand(2)}'" if !logical_operand(2).blank?
    end

    sales_rep_condition = ""
    if !sales_rep_id.blank?
      sales_rep_condition = "AND (contacts.sales_rep_user_id = #{sales_rep_id} OR companies.sales_rep_user_id = #{sales_rep_id} OR estimates.sales_rep_user_id = #{sales_rep_id})"
    end
    taken_by_condition = ""
    if !taken_by_id.blank?
      taken_by_condition = "AND (estimates.taken_by_user_id = #{taken_by_id})"
    end

    %Q{
      SELECT null
      FROM estimates
      WHERE contact_id = contacts.id
      AND estimates.voided = false
      AND estimates.deleted = false
      #{modifier_condition}
      #{modifier2_condition}
      #{sales_rep_condition}
      #{taken_by_condition}
      #{primary_condition}
    }
  end

  def single_estimate_text(tenant)
    negate_text = "#{negate_text("Does not")} have a " if negate
    between_value = " and #{value2}" if logical_operand_name == "between"
    result = "#{negate_text}#{"single".humanize(capitalize: negate ? false : true)} estimate #{logical_operand_name.humanize(capitalize: false)} #{value}#{between_value}"
    if !modifier.blank?
      result = "#{result} #{modifier_operand} #{modifier_value}"
      result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    end
    if !modifier2.blank?
      result = "#{result} with a status of #{logical_operand_name(2).humanize(capitalize: false)}" if !logical_operand(2).blank?
    end
    if !sales_rep_id.blank?
      sales_rep = User.find(sales_rep_id)
      result = "#{result} - Sales Rep: #{sales_rep.full_name}"
    end
    if !taken_by_id.blank?
      taken_by = User.find(taken_by_id)
      result = "#{result} - Taken By: #{taken_by.full_name}"
    end
    result
  end

  def sales_per_month(tenant)
    if logical_operand_name == "between"
      primary_condition = "HAVING COUNT(invoices.id) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value)} AND #{ActiveRecord::Base::sanitize(value2)}"
    else
      primary_condition = "HAVING COUNT(invoices.id) #{logical_operand} #{ActiveRecord::Base::sanitize(value)}"
    end

    date1, date2 = get_modifier_dates(tenant)
    start_date, end_date = set_month_range(date1, date2)

    if start_date.month == end_date.month && start_date.year == end_date.year
      number_of_months = 1
    else
      number_of_months = (end_date.year * 12 + end_date.month) - (start_date.year * 12 + start_date.month) + 1
    end
    modifier_condition = "AND invoices.pickup_date BETWEEN #{ActiveRecord::Base::sanitize(start_date)} AND #{ActiveRecord::Base::sanitize(end_date)}"
    modifier_condition2 = "HAVING COUNT(*) = #{number_of_months}"

    %Q{
      SELECT null
      FROM (
        SELECT null
        FROM invoices
        WHERE invoices.contact_id = contacts.id
        #{"AND #{Invoice.INVOICED}" if Platform.is_mbe?(tenant)}
        AND invoices.voided = false
        AND invoices.deleted = false
        AND pickup_date IS NOT NULL
        #{modifier_condition}
        GROUP BY date_trunc('month', pickup_date)
        #{primary_condition}
      ) by_month
      #{modifier_condition2}

    }
  end

  def sales_per_month_text(tenant)
    date1, date2 = get_modifier_dates(tenant)
    start_date, end_date = set_month_range(date1, date2)

    start_month = start_date.strftime("%B %Y")
    end_month = end_date.strftime("%B %Y")

    if negate
      preamble = "#{negate_text("Does not")} have "
    else
      preamble = "Has "
    end

    result = "#{preamble}#{logical_operand_name.humanize(capitalize: false)} #{value} sales every month between #{start_month} and #{end_month}"
    result
  end

  def sales_per_month_by_company(tenant)
    if logical_operand_name == "between"
      primary_condition = "HAVING COUNT(invoices.id) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value)} AND #{ActiveRecord::Base::sanitize(value2)}"
    else
      primary_condition = "HAVING COUNT(invoices.id) #{logical_operand} #{ActiveRecord::Base::sanitize(value)}"
    end

    date1, date2 = get_modifier_dates(tenant)
    start_date, end_date = set_month_range(date1, date2)

    if start_date.month == end_date.month && start_date.year == end_date.year
      number_of_months = 1
    else
      number_of_months = (end_date.year * 12 + end_date.month) - (start_date.year * 12 + start_date.month) + 1
    end
    modifier_condition = "AND invoices.pickup_date BETWEEN #{ActiveRecord::Base::sanitize(start_date)} AND #{ActiveRecord::Base::sanitize(end_date)}"
    modifier_condition2 = "HAVING COUNT(*) = #{number_of_months}"

    %Q{
      SELECT null
      FROM (
        SELECT null
        FROM invoices
        WHERE invoices.company_id = contacts.company_id
        #{"AND #{Invoice.INVOICED}" if Platform.is_mbe?(tenant)}
        AND invoices.voided = false
        AND invoices.deleted = false
        AND pickup_date IS NOT NULL
        #{modifier_condition}
        GROUP BY date_trunc('month', pickup_date)
        #{primary_condition}
      ) by_month
      #{modifier_condition2}

    }
  end

  def sales_per_month_by_company_text(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if date1.nil?
      date1 = DateTime.now
      date2 = DateTime.now - 1.year
    end

    if date2.nil?
      if modifier_operand == "on"
        date2 = date1
      elsif modifier_operand == "before"
        date2 = date1 - 1.year
      else
        date2 = DateTime.now
      end
    end

    start_date = date1.beginning_of_month
    end_date = date2.end_of_month
    if start_date > end_date
      start_date = date2.beginning_of_month
      end_date = date1.end_of_month
    end

    start_month = start_date.strftime("%B %Y")
    end_month = end_date.strftime("%B %Y")

    if negate
      preamble = "#{negate_text("Does not")} have "
    else
      preamble = "Has "
    end

    result = "#{preamble}#{logical_operand_name.humanize(capitalize: false)} #{value} sales by company every month between #{start_month} and #{end_month}"
    result
  end

  # CREATED DATE
  def contact_created_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING i_contacts.source_created_at BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING i_contacts.source_created_at #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end


    %Q{
      SELECT null
      FROM contacts i_contacts
      WHERE i_contacts.id = contacts.id
      GROUP BY id
      #{primary_condition}
    }
  end

  def contact_created_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "Contact created date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def company_created_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING companies.company_created_date BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING companies.company_created_date #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM companies
      WHERE companies.id = contacts.company_id
      GROUP BY id
      #{primary_condition}
    }
  end

  def company_created_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "Company created date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def industry(tenant)
    industries = value.try(:split, ",")
    sanatized_csv = industries.map { |s| "'#{s}'" }.to_csv
    %Q{
      SELECT null
      FROM companies
      WHERE companies.id = contacts.company_id
      AND (
        companies.custom_data->'category'->>'subIndustry' IN (#{sanatized_csv})
        OR (
          (companies.custom_data->'category'->>'subIndustry' IS NULL OR companies.custom_data->'category'->>'subIndustry' = '')
          AND
          companies.clearbit_data->'category'->>'subIndustry' IN (#{sanatized_csv})
        )
      )
      GROUP BY id
    }
  end

  def industry_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "Company industry is #{negate_text}#{value}"
    result
  end

  def last_order_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING MAX(invoices.ordered_date) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING MAX(invoices.ordered_date) #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      AND invoices.voided = false
      AND invoices.deleted = false
      #{primary_condition}
    }
  end

  def last_order_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "Last order date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  # LAST ESTIMATE

  def last_estimate_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING MAX(estimates.ordered_date) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING MAX(estimates.ordered_date) #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM estimates
      WHERE contact_id = contacts.id
      AND estimates.voided = false
      AND estimates.deleted = false

      #{primary_condition}
    }
  end

  def last_estimate_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "Last estimate date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def first_shipment_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING MIN(shipments.shipment_date) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING MIN(shipments.shipment_date) #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM shipments
      WHERE contact_id = contacts.id
      AND shipments.deleted = false

      #{primary_condition}
    }
  end

  def first_shipment_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "First shipment date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def last_shipment_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING MAX(shipments.shipment_date) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING MAX(shipments.shipment_date) #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM shipments
      WHERE contact_id = contacts.id
      AND shipments.deleted = false

      #{primary_condition}
    }
  end

  def last_shipment_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "Last shipment date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def first_order_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING MIN(invoices.ordered_date) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING MIN(invoices.ordered_date) #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      AND invoices.voided = false
      AND invoices.deleted = false

      #{primary_condition}
    }
  end

  def first_order_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "First order date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def first_sale_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING MIN(invoices.pickup_date) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING MIN(invoices.pickup_date) #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      #{"AND #{Invoice.INVOICED}" if Platform.is_mbe?(tenant)}
      AND invoices.voided = false
      AND invoices.deleted = false
      AND invoices.pickup_date IS NOT NULL

      #{primary_condition}
    }
  end

  def first_sale_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "First sale date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def first_estimate_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING MIN(estimates.ordered_date) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING MIN(estimates.ordered_date) #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM estimates
      WHERE contact_id = contacts.id
      AND estimates.voided = false
      AND estimates.deleted = false

      #{primary_condition}
    }
  end

  def first_estimate_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "First estimate date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def estimate_ordered_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING MIN(estimates.ordered_date) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING MIN(estimates.ordered_date) #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM estimates
      WHERE contact_id = contacts.id
      AND estimates.voided = false
      AND estimates.deleted = false

      #{primary_condition}
    }
  end

  def estimate_ordered_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "Estimate order date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def invoice_ordered_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING MIN(invoices.ordered_date) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING MIN(invoices.ordered_date) #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      AND invoices.voided = false
      AND invoices.deleted = false

      #{primary_condition}
    }
  end

  def invoice_ordered_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "Invoice order date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def days_since_single_sale(tenant)
    if logical_operand_name == "between"
      primary_condition = "BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value.to_i)} AND #{ActiveRecord::Base::sanitize(value2.to_i)}"
    else
      primary_condition = "#{logical_operand} #{ActiveRecord::Base::sanitize(value.to_i)}"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE invoices.contact_id = contacts.id
      AND invoices.pickup_date IS NOT NULL
      AND invoices.voided = FALSE
      AND invoices.deleted = FALSE
      HAVING COUNT(*) = 1
      AND DATE_PART('day', NOW() - MIN(invoices.pickup_date)) #{primary_condition}
    }
  end

  def days_since_single_sale_text(tenant)
    negate_text = "#{negate_text("no")} " if negate
    between_value = " and #{value2}" if logical_operand_name == "between"
    result = "Contact has #{negate_text}#{logical_operand_name.humanize(capitalize: false)} #{value}#{between_value} days since their first and only sale"
    result
  end

  def last_sale_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING MAX(invoices.pickup_date) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING MAX(invoices.pickup_date) #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      AND invoices.voided = false
      AND invoices.deleted = false
      #{primary_condition}
    }
  end

  def last_sale_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "Last pickup date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def last_pickup_date(tenant)
    date1, date2 = get_modifier_dates(tenant)
    if !date1.nil? && !date2.nil?
      primary_condition = "HAVING MAX(invoices.pickup_date) BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
    else
      primary_condition = "HAVING MAX(invoices.pickup_date) #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      AND invoices.voided = false
      AND invoices.deleted = false
      #{primary_condition}
    }
  end

  def last_pickup_date_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    result = "Last pickup date was #{negate_text}#{modifier_operand} #{modifier_value}"
    result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    result
  end

  def days_since_last_pickup_date(tenant)
    if logical_operand_name == "between"
      primary_condition = "HAVING (NOW() - MAX(invoices.pickup_date)) BETWEEN SYMMETRIC interval '#{value.to_i} day' AND interval '#{value2.to_i} day'"
    else
      primary_condition = "HAVING (NOW() - MAX(invoices.pickup_date)) #{logical_operand} interval '#{value.to_i} day'"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      AND invoices.voided = false
      AND invoices.deleted = false
      #{primary_condition}
    }
  end

  def days_since_last_sale_date_text(tenant)
    negate_text = "#{negate_text("Does not")} have " if negate
    result = "#{negate_text}#{logical_operand_name.humanize(capitalize: negate ? false : true)} #{value} days since last pickup date."
    result
  end

  def days_since_last_sale_date(tenant)
    if logical_operand_name == "between"
      primary_condition = "HAVING (NOW() - MAX(invoices.pickup_date)) BETWEEN SYMMETRIC interval '#{value.to_i} day' AND interval '#{value2.to_i} day'"
    else
      primary_condition = "HAVING (NOW() - MAX(invoices.pickup_date)) #{logical_operand} interval '#{value.to_i} day'"
    end

    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      #{"AND #{Invoice.INVOICED}" if Platform.is_mbe?(tenant)}
      AND invoices.voided = false
      AND invoices.deleted = false
      #{primary_condition}
    }
  end

  def days_since_last_pickup_date_text(tenant)
    negate_text = "#{negate_text("Does not")} have " if negate
    result = "#{negate_text}#{logical_operand_name.humanize(capitalize: negate ? false : true)} #{value} days since last pickup date."
    result
  end

  def email_address(tenant)
    if operand == "exists"
      "(contacts.email LIKE '%@%')"
    else
      "(contacts.email NOT LIKE '%@%')"
    end
  end

  def email_address_text(tenant)
    if (!negate && operand != "exists") || (negate && operand == "exists")
      "Email address #{negate_text("does not")} exist"
    else
      "Email address exists"
    end
  end

  def phone_number(tenant)
    if operand == "exists"
      "(length(contacts.phone) > 0 OR length(contacts.mobile) > 0)"
    else
      "((contacts.phone IS NULL OR length(contacts.phone) = 0) AND (contacts.mobile IS NULL OR length(contacts.mobile) = 0))"
    end
  end

  def phone_number_text(tenant)
    if (!negate && operand != "exists") || (negate && operand == "exists")
      "Phone number #{negate_text("does not")} exist"
    else
      "Phone number exists"
    end
  end

  def prospect(tenant)
    "companies.prospect = #{logical_operand}"
  end

  def prospect_text(tenant)
    negate_text = "#{negate_text("not")} " if (!negate && operand != "true") || (negate && operand == "true")
    "Is #{negate_text}a prospect"
  end

  def lead_stage(tenant)
    primary_condition = ""
    if value == "any"
      primary_condition = "c.prospect_status_id IS NOT NULL"
    else
      # primary_condition = "c.prospect_status_id = #{ActiveRecord::Base::sanitize(value)}"
      primary_condition = "ps_old.id = #{ActiveRecord::Base::sanitize(value)}"
    end
    %Q{
      SELECT null
      FROM contacts c
      LEFT JOIN prospect_statuses ON prospect_statuses.id = c.prospect_status_id
      LEFT JOIN prospect_statuses ps_old ON ps_old.name = prospect_statuses.name
      WHERE c.id = contacts.id
      AND #{primary_condition}
    }
  end

  def lead_stage_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    if value == "any"
      result = "Contact is #{negate_text}a Lead"
    else
      lead_stage = ProspectStatus.where(id: value).first
      lead_stage_name = "Unknown"
      lead_stage_name = lead_stage.name if lead_stage
      result = "Lead stage is #{negate_text}#{lead_stage_name}"
    end
    result
  end

  def lead_type(tenant)
    "contacts.lead_type_id #{logical_operand} #{ActiveRecord::Base::sanitize(value)}"
  end

  def lead_type_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    lead_type = LeadType.where(id: value).first
    lead_type_name = "Unknown"
    lead_type_name = lead_type.name if lead_type
    result = "Lead type is #{negate_text}#{lead_type_name}"
    result
  end

  def statement_contact(tenant)
    "companies.source_billtocontact_id::TEXT = contacts.platform_id"
  end

  def statement_contact_text(tenant)
    negate_text = "#{negate_text("not")} " if (!negate && operand != "true") || (negate && operand == "true")
    "Is #{negate_text}a statement contact"
  end

  def invoice_contact(tenant)
    "companies.source_contact_id::TEXT = contacts.platform_id"
  end

  def invoice_contact_text(tenant)
    negate_text = "#{negate_text("not")} " if (!negate && operand != "true") || (negate && operand == "true")
    "Is #{negate_text}a invoice contact"
  end

  def walk_in(tenant)
    "companies.walk_in = #{logical_operand}"
  end

  def walk_in_text(tenant)
    negate_text = "#{negate_text("not")} " if (!negate && operand != "true") || (negate && operand == "true")
    "Is #{negate_text}a walk in contact"
  end

  def company_status(tenant)
    "companies.status #{logical_operand} #{ActiveRecord::Base::sanitize(value)}"
  end

  def company_status_text(tenant)
    status = ContactListRule.company_status.select { |possible_value| possible_value[1] == value }.try(:first).try(:first)
    negate_text = "#{negate_text("not")} " if (!negate && operand == "is_not") || (negate && operand != "is_not")
    "Company status is #{negate_text}#{status}".humanize
  end

  def buy_frequency(tenant)
    if logical_operand_name == "between"
      "contacts.days_outside_buy_freq BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value.to_i)} AND #{ActiveRecord::Base::sanitize(value2.to_i)}"
    else
      "contacts.days_outside_buy_freq #{logical_operand} #{ActiveRecord::Base::sanitize(value.to_i)}"
    end
  end

  def buy_frequency_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    between_value = " and #{value2}" if logical_operand_name == "between"
    result = "Contact is #{negate_text}#{logical_operand_name.humanize(capitalize: false)} #{value}#{between_value} days outside of their buy frequency"
    result
  end

  def orders_in_progress(tenant)
    %Q{
      SELECT null
      FROM invoices
      WHERE contact_id = contacts.id
      AND invoices.voided = false
      AND invoices.deleted = false
      HAVING BOOL_OR(invoices.on_pending_list) = #{logical_operand}
    }
  end

  def orders_in_progress_text(tenant)
    condidtion = (!negate && operand == "true") || (negate && operand != "true") ? "has" : "#{negate_text("does not")} have any"
    "Contact #{condidtion} orders in progress"
  end

  def address(tenant)
    negate_query = ""
    if operand != "exists"
      negate_query = "NOT "
    end

    %Q{
      (
        #{negate_query}EXISTS (
          SELECT null
          FROM addresses
          WHERE (addresses.id = contacts.address_id OR addresses.id = companies.invoice_address_id)
          AND ((addresses.street1 IS NOT NULL AND addresses.street1 != '') OR (addresses.street2 IS NOT NULL AND addresses.street2 != ''))
        )
      )
    }
  end

  def address_text(tenant)
    if (!negate && operand != "exists") || (negate && operand == "exists")
      "Address #{negate_text("does not")} exist"
    else
      "Address exists"
    end
  end

  def company_ranking(tenant)
    if logical_operand_name == "between"
      "companies.rolling_12_month_rank BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value.to_i)} AND #{ActiveRecord::Base::sanitize(value2.to_i)}"
    else
      "companies.rolling_12_month_rank #{logical_operand} #{ActiveRecord::Base::sanitize(value.to_i)}"
    end
  end

  def company_ranking_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    between_value = " and #{value2}" if logical_operand_name == "between"
    result = "Company rank is #{negate_text}#{logical_operand_name.humanize(capitalize: false)} #{value}#{between_value}"
    result
  end

  def contact_ranking(tenant)
    min_sales_offset = 0
    min_sales_offset = value.to_i - 1 if value.to_i > 0
    min_sales = Contact.where(tenant_id: tenant.id).order("contacts.rolling_12_month_sales DESC NULLS LAST").offset(min_sales_offset).limit(1).pluck(:rolling_12_month_sales).first
    if !min_sales.nil?
      min_sales = 0.000001 if min_sales == 0
      max_sales_offset = 0
      max_sales_offset = value2.to_i - 1 if value2.to_i > 0
      max_sales = Contact.where(tenant_id: tenant.id).order("contacts.rolling_12_month_sales DESC NULLS LAST").offset(max_sales_offset).limit(1).pluck(:rolling_12_month_sales).first
      if logical_operand_name == "between"
        "contacts.rolling_12_month_sales BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(min_sales)} AND #{ActiveRecord::Base::sanitize(max_sales)}" if !min_sales.nil?
      else
        "contacts.rolling_12_month_sales #{logical_operand} #{ActiveRecord::Base::sanitize(min_sales)}"
      end
    end
  end

  def contact_ranking_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    between_value = "and #{value2} " if logical_operand_name == "between"
    result = "Contact rank is #{negate_text}#{logical_operand_name.humanize(capitalize: false)} #{value} #{between_value}"
    result
  end

  def sale_name(tenant)
    ""
    # result = Contact.joins(:invoices)
    # filters = value.split(',').map{|s| "#{s.squish}"}.join('|')
    # filters = ActiveRecord::Base::sanitize("\\y(#{filters})")
    # result = result.where("invoices.name ~* #{filters}")
    # result
  end

  def sale_name_text(tenant)
    "NO LONGER VALID"
    # if negate
    #   "Sale name #{negate_text("does not")} match #{value}"
    # else
    #   "Sale name matches #{value}"
    # end
  end

  def sale_name_contextuals(tenant, contacts)
    result = {}
    # filters = value.split(',').map{|s| "#{s.squish}"}.join('|')
    # filters = ActiveRecord::Base::sanitize("\\y(#{filters})")
    # sales = Sale.joins(:contact).where(contact_id: contacts.map{|contact| contact.id}).where("invoices.name ~* #{filters}").order(created_at: :asc)
    #
    # contacts.each do |contact|
    #   invoice_numbers = []
    #   invoice_name = []
    #   sales.each do |sale|
    #     if sale.contact_id == contact.id
    #       invoice_numbers << sale.invoice_number
    #       invoice_name << sale.name
    #     end
    #   end
    #   result[contact.id] = {invoice_numbers: invoice_numbers, invoice_name: invoice_name}
    # end
    result
  end

  def tag_match(tenant)
    negate_query = operand != "matches" ? "NOT" : ""
    query = %Q{
      #{negate_query} EXISTS (
        SELECT null
        FROM tag_categories
        INNER JOIN tags ON tag_categories.id = tags.tag_category_id
          AND tags.deleted = FALSE
        WHERE
          tag_categories.id = #{ActiveRecord::Base::sanitize(value.to_i)}
          AND tag_categories.performing_cleanup = FALSE
          AND tag_categories.deleted = FALSE
          AND ( ( tag_categories.tenant_id = #{tenant.id} OR tag_categories.tenant_id IS NULL ) AND tag_categories.enterprise_id = #{tenant.enterprise_id} )
          AND tags.tenant_id = #{tenant.id}
          AND tags.taggable_type = 'Contact'
          AND tags.taggable_id = contacts.id
      )
    }
    query
  end

  def tag_match_text(tenant)
    tag_category = TagCategory.unscoped.where(id: value).first.try(:name)
    if (!negate && operand != "matches") || (negate && operand == "matches")
      "Tag #{negate_text("does not")} match #{tag_category}"
    else
      "Tag matches #{tag_category}"
    end
  end

  # def tag_match_contextuals(tenant, contacts)
  #   result = {}
  #   invoices = Invoice.joins(:contact).joins("INNER JOIN tags ON tags.taggable_id = invoices.id AND tags.taggable_type = 'Invoice'").where(contact_id: contacts.map{|contact| contact.id}).where(tags: {tag_category_id: value.to_i}).order(created_at: :asc)

  #   contacts.each do |contact|
  #     invoice_numbers = []
  #     invoice_name = []
  #     invoices.each do |invoice|
  #       if invoice.contact_id == contact.id
  #         invoice_numbers << invoice.invoice_number
  #         invoice_name << invoice.name
  #       end
  #     end
  #     result[contact.id] = {invoice_numbers: invoice_numbers, invoice_name: invoice_name}
  #   end
  #   result
  # end

  def sent_campaign(tenant)
    primary_condition = ""
    if !value2.blank?
      if value2 == "opened"
        primary_condition = "AND campaign_messages.opened = true"
      elsif value2 == "not_opened"
        primary_condition = "AND campaign_messages.opened = false"
      end
    end
    modifier_condition = ""
    if !modifier.blank?
      date1, date2 = get_modifier_dates(tenant)
      if !date1.nil? && !date2.nil?
        modifier_condition = "AND campaigns.created_at BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
      elsif !date1.nil?
        if logical_operand(1) == "="
          modifier_condition = "AND campaigns.created_at BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1.beginning_of_day)} AND #{ActiveRecord::Base::sanitize(date1.end_of_day)}"
        else
          modifier_condition = "AND campaigns.created_at #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
        end
      end
    end
    %Q{
      SELECT null
      FROM campaign_messages
      INNER JOIN campaigns ON campaigns.id = campaign_messages.campaign_id
      WHERE campaign_messages.contact_id = contacts.id
      AND campaigns.parent_id = #{value}
      AND campaigns.test = false
      AND campaign_messages.sent = true
      #{primary_condition}
      #{modifier_condition}
    }
  end

  def sent_campaign_text(tenant)
    result = ""
    campaign = Campaign.unscoped.where(id: value).first.try(:name)
    if (!negate && operand != "sent") || (negate && operand == "sent")
      result = "Was #{negate_text("not")} sent campaign: #{campaign}"
    else
      result = "Was sent campaign: #{campaign}"
    end
    if !modifier.blank?
      result = "#{result} #{modifier_operand} #{modifier_value}"
      result = "#{result} and #{modifier_value2}" if modifier_operand == "between"
    end

    result
  end

  def first_name(tenant)
    "contacts.first_name IS NOT NULL AND contacts.first_name != ''"
  end

  def first_name_text(tenant)
    if (!negate && operand != "exists") || (negate && operand == "exists")
      "First name #{negate_text("does not")} exist"
    else
      "First name exists"
    end
  end

  def estimates_in_progress(tenant)
    condition = "AND estimates.voided = false AND estimates.deleted = false HAVING BOOL_OR(estimates.on_pending_list) = true"
    if !logical_operand
      condition = "AND ((estimates.voided = false AND estimates.deleted = false) OR estimates.on_pending_list IS NULL) HAVING (BOOL_OR(estimates.on_pending_list) = false OR BOOL_OR(estimates.on_pending_list) IS NULL)"
    end
    %Q{
      SELECT null
      FROM contacts i_contacts
      LEFT OUTER JOIN estimates ON estimates.contact_id = i_contacts.id
      WHERE i_contacts.id = contacts.id
      #{condition}
    }
  end

  def estimates_in_progress_text(tenant)
    condidtion = (!negate && operand == "true") || (negate && operand != "true") ? "has" : "#{negate_text("does not")} have any"
    "Contact #{condidtion} estimates in progress"
  end

  def estimates_status(tenant)
    modifier_condition = ""
    if !modifier.blank?
      date1, date2 = get_modifier_dates(tenant)
      if !date1.nil? && !date2.nil?
        modifier_condition = "AND estimates.ordered_date BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(date1)} AND #{ActiveRecord::Base::sanitize(date2)}"
      elsif !date1.nil?
        modifier_condition = "AND estimates.ordered_date #{logical_operand(1)} #{ActiveRecord::Base::sanitize(date1)}"
      end
    end

    %Q{
      SELECT null
      FROM estimates
      WHERE contact_id = contacts.id
      AND estimates.voided = false
      AND estimates.deleted = false
      AND estimates.status = '#{logical_operand}'
      #{modifier_condition}
    }
  end

  def estimates_status_text(tenant)
    modifier_text = ""
    if !modifier.blank?
      modifier_text = " #{modifier_operand} #{modifier_value}"
      modifier_text = "#{modifier_text} and #{modifier_value2}" if modifier_operand == "between"
    end
    condidtion = !negate ? "has" : "#{negate_text("does not")} have any"
    "Contact #{condidtion} estimates with a status of #{logical_operand}#{modifier_text}"
  end

  def company_growth(tenant)
    if logical_operand_name == "between"
      "companies.growth_percentage BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value)} AND #{ActiveRecord::Base::sanitize(value2)}"
    else
      "companies.growth_percentage #{logical_operand} #{ActiveRecord::Base::sanitize(value)}"
    end
  end

  def company_growth_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    between_value = " and #{value2}" if logical_operand_name == "between"
    result = "Company growth is #{negate_text}#{logical_operand_name.humanize(capitalize: false)} #{value}#{between_value}"
    result
  end

  def contact_growth(tenant)
    if logical_operand_name == "between"
      "contacts.growth_percentage BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value)} AND #{ActiveRecord::Base::sanitize(value2)}"
    else
      "contacts.growth_percentage #{logical_operand} #{ActiveRecord::Base::sanitize(value)}"
    end
  end

  def contact_growth_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    between_value = " and #{value2}" if logical_operand_name == "between"
    result = "Contact growth is #{negate_text}#{logical_operand_name.humanize(capitalize: false)} #{value}#{between_value}"
    result
  end

  def average_invoice(tenant)
    if logical_operand_name == "between"
      "contacts.average_invoice BETWEEN SYMMETRIC #{ActiveRecord::Base::sanitize(value)} AND #{ActiveRecord::Base::sanitize(value2)}"
    else
      "contacts.average_invoice #{logical_operand} #{ActiveRecord::Base::sanitize(value)}"
    end
  end

  def average_invoice_text(tenant)
    negate_text = "#{negate_text("not")} " if negate
    between_value = " and #{value2}" if logical_operand_name == "between"
    result = "Average invoice is #{negate_text}#{logical_operand_name.humanize(capitalize: false)} #{value}#{between_value}"
    result
  end

  def sales_rep(tenant)
    if tenant.sales_rep_for_locations
      if operand != "is"
        "contacts.location_user_id IS DISTINCT FROM #{ActiveRecord::Base::sanitize(sales_rep_id)} AND companies.location_user_id IS DISTINCT FROM #{ActiveRecord::Base::sanitize(sales_rep_id)}"
      else
        "contacts.location_user_id IS NOT DISTINCT FROM #{ActiveRecord::Base::sanitize(sales_rep_id)} OR companies.location_user_id IS NOT DISTINCT FROM #{ActiveRecord::Base::sanitize(sales_rep_id)}"
      end
    else
      if operand != "is"
        "contacts.sales_rep_user_id IS DISTINCT FROM #{ActiveRecord::Base::sanitize(sales_rep_id)} AND companies.sales_rep_user_id IS DISTINCT FROM #{ActiveRecord::Base::sanitize(sales_rep_id)}"
      else
        "contacts.sales_rep_user_id IS NOT DISTINCT FROM #{ActiveRecord::Base::sanitize(sales_rep_id)} OR companies.sales_rep_user_id IS NOT DISTINCT FROM #{ActiveRecord::Base::sanitize(sales_rep_id)}"
      end
    end
  end

  def sales_rep_text(tenant)
    negate_text = "#{negate_text("not")} " if (!negate && operand != "is") || (negate && operand == "is")

    if tenant.sales_rep_for_locations
      location = Location.where(id: sales_rep_id).first
      location_name = location.try(:name) || "Unknown"
      result = "Location is #{negate_text} #{location_name}"
      result
    else
      sales_rep = User.where(id: sales_rep_id).first
      sales_rep_name = sales_rep.try(:full_name) || "Unknown"
      result = "Sales Rep is #{negate_text} #{sales_rep_name}"
      result
    end
  end

  def privacy(tenant)
    "contacts.privacy_data->>#{ActiveRecord::Base::sanitize(value)} IS NOT NULL AND (contacts.privacy_data->#{ActiveRecord::Base::sanitize(value)}->'state') = '1'"
  end

  def privacy_text(tenant)
    negate_text = "#{negate_text("No")} " if negate
    privacy = "Privacy"
    privacy.downcase! if negate
    result = "#{negate_text}#{privacy} for #{value.titleize}"
    result
  end
end
