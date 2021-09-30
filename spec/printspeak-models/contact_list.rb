class ContactList < ActiveRecord::Base
  validates :name, length: { minimum: 4 }

  belongs_to :tenant
  belongs_to :enterprise
  has_many :rules, class_name: "ContactListRule", dependent: :destroy
  has_many :exclusions, class_name: "ContactListExclusion", dependent: :destroy
  has_many :counts, class_name: "ContactListCount", dependent: :destroy
  has_and_belongs_to_many :campaigns, -> { uniq }
  has_and_belongs_to_many :contacts, -> { uniq }



  scope :tenant_scope, lambda { |tenant_id| where("contact_lists.tenant_id = ? OR contact_lists.global = ?", tenant_id, true) }
  scope :user_scope, lambda { |user_id| joins("INNER JOIN users ON users.id = '#{user_id}'").where("contact_lists.hide_from_tenant = 'false' OR users.role = 'Super User' OR users.role = 'Enterprise User'", user_id) }

  def all_contacts(tenant, page = nil, per = nil, rule_based_only = false, campaign = nil, location = nil, exclude_oversend = false, only_oversend = false, search = nil, sort = nil, direction = nil, background = false)
    page ||= 1
    query = all_contacts_query(tenant, page, per, rule_based_only, campaign, location, exclude_oversend, only_oversend, search, sort, direction, background)
    if query.blank?
      result = Contact.none
      total_count = 0
    else
      start_time = Time.now
      result = Contact.find_by_sql(query)
      total_count = result.first.try(:total_count) || 0
      end_time = Time.now

      if !rule_based_only && campaign.nil? && location.nil? && exclude_oversend == false && only_oversend == false
        count = counts.find_or_initialize_by(tenant_id: tenant.id)
        count.assign_attributes(total_count: total_count, generate_duration: end_time - start_time)
        count.save
      end
    end
    if page.to_i <= 0
      Kaminari.paginate_array(result, total_count: total_count).page(0).per(total_count)
    else
      Kaminari.paginate_array(result, total_count: total_count).page(page).per(per)
    end
  end

  def all_contacts_query(tenant, page = nil, per = nil, rule_based_only = false, campaign = nil, location = nil, exclude_oversend = false, only_oversend = false, search = nil, sort = nil, direction = nil, background = false)
    page ||= 1
    per ||= 10
    offset = (page.to_i - 1) * per


    rule_conditions = ""
    rules.order(id: :asc).each do |rule|
      rule_sql = rule.get_sql(tenant)
      rule_conditions << rule_sql unless rule_sql.blank?
    end

    if !rule_conditions.blank?
      if !location.nil?
        if location.id.nil?
          location_condition = "AND (contacts.location_user_id IS NULL AND companies.location_user_id IS NULL)"
        else
          default_location = " OR (contacts.location_user_id IS NULL AND companies.location_user_id IS NULL)" if location.default
          location_condition = "AND (contacts.location_user_id = #{location.id}#{default_location} OR (contacts.location_user_id IS NULL AND companies.location_user_id = #{location.id}))"
        end
      end

      unless rule_based_only && !only_oversend
        exclude_ids = exclusions.where(tenant_id: tenant.id).pluck(:contact_id)
        exclusions_query = "AND contacts.id NOT IN (#{exclude_ids.to_csv})" if exclude_ids.any?

        include_ids = contacts.where(tenant_id: tenant.id).pluck(:id)
        inclusions_query = "OR (contacts.id IN (#{include_ids.to_csv})#{location_condition})" if include_ids.any? && only_oversend == false
      end

      if !campaign.nil? && !only_oversend
        campaign_exclude_ids = campaign.exclusions.pluck(:contact_id)
        campaign_exclusions_query = "AND contacts.id NOT IN (#{campaign_exclude_ids.to_csv})" if campaign_exclude_ids.any?
      end

      if exclude_oversend || only_oversend
        min_resend = tenant.try(:campaign_min_resend_days).try(:days)
        min_resend = 25.days if min_resend.nil?
        min_resend_time = (Time.now - min_resend).to_formatted_s(:db)
        oversend_exclusions_query = ""
        # oversend_exclusions_query = %Q{
        #   SELECT null
        #   FROM campaign_messages
        #   JOIN campaigns ON campaigns.id = campaign_messages.campaign_id
        #   JOIN contacts AS message_contacts ON message_contacts.id = campaign_messages.contact_id
        #   WHERE campaigns.test = FALSE
        #   AND campaigns.tenant_id = #{tenant.id}
        #   AND (
        #     (campaign_messages.sent = TRUE AND campaign_messages.sent_date > '#{min_resend_time}')
        #     OR (campaigns.paused = FALSE AND campaign_messages.sent != TRUE AND campaign_messages.failed != TRUE AND campaign_messages.created_at > '#{min_resend_time}')
        #   )
        #   AND LOWER(TRIM(message_contacts.email)) = LOWER(BTRIM(contacts.email))
        # }
        oversend_query = %Q{
          SELECT ic.id
          FROM contacts ic
          WHERE ic.tenant_id = #{tenant.id}
          AND EXISTS(
            SELECT null
            FROM campaign_messages
            INNER JOIN campaigns ON campaigns.id = campaign_messages.campaign_id
            INNER JOIN contacts AS message_contacts ON message_contacts.tenant_id = #{tenant.id} AND message_contacts.id = campaign_messages.contact_id
            WHERE campaigns.test = FALSE
            AND campaigns.tenant_id = #{tenant.id}
            AND (
              (campaign_messages.sent = TRUE AND campaign_messages.sent_date > '#{min_resend_time}')
              OR (campaigns.paused = FALSE AND campaign_messages.sent != TRUE AND campaign_messages.failed != TRUE AND campaign_messages.created_at > '#{min_resend_time}')
            )
            AND LOWER(TRIM(message_contacts.email)) = LOWER(BTRIM(ic.email))
          )
        }
        oversend_ids = Contact.find_by_sql(oversend_query).to_a.map { |s| s.id }
        if oversend_ids.count > 0
          if only_oversend
            oversend_exclusions_query = "AND contacts.id IN (#{oversend_ids.to_csv})"
          else
            oversend_exclusions_query = "AND contacts.id NOT IN(#{oversend_ids.to_csv})"
          end
        else
          if only_oversend
            oversend_exclusions_query = "AND false"
          end
        end
      end

      if !search.nil?
        search = "%#{search}%"
        search_query = "AND ((trim(regexp_replace(COALESCE(contacts.first_name, '') || ' ' || COALESCE(contacts.last_name, ''), '\s+', ' ', 'g')) ILIKE #{ActiveRecord::Base::sanitize(search)}) OR companies.name ILIKE #{ActiveRecord::Base::sanitize(search)})"
      end

      case sort
      when "name"
        sort_query = "contacts.first_name #{direction ? direction : 'ASC' } NULLS LAST"
      when "company"
        sort_query = "MIN(companies.name) #{direction ? direction : 'ASC' } NULLS LAST, contacts.first_name ASC NULLS LAST"
      when "rolling12ly"
        sort_query = "contacts.rolling_12_month_sales_ly #{direction ? direction : 'DESC' } NULLS LAST, contacts.first_name ASC NULLS LAST"
      when "growth"
        sort_query = "contacts.growth_percentage #{direction ? direction : 'DESC' } NULLS LAST, contacts.first_name ASC NULLS LAST"
      when "status"
        sort_query = "MIN(companies.status) #{direction ? direction : 'ASC  ' } NULLS LAST, contacts.first_name ASC NULLS LAST"
      when "lastorder"
        sort_query = "contacts.latest_order_date #{direction ? direction : 'DESC' } NULLS LAST, contacts.first_name ASC NULLS LAST"
      else
        sort_query = "contacts.rolling_12_month_sales #{direction ? direction : 'DESC' } NULLS LAST, contacts.first_name ASC NULLS LAST"
      end

      limit = "LIMIT #{per} OFFSET #{offset}" unless page.to_i <= 0

      selector = "contacts.*"
      selector = "contacts.id" if background

      query = %Q{
        SELECT #{selector}, (COUNT(*) OVER()) AS total_count
        FROM contacts
        LEFT OUTER JOIN companies ON companies.id = contacts.company_id
        WHERE contacts.tenant_id = #{tenant.id}
        #{account_type_query}
        AND contacts.deleted = false
        AND contacts.unsubscribed = false
        AND companies.marketing_do_not_mail = false
        AND NOT EXISTS ( SELECT null FROM email_soft_bounces WHERE email_soft_bounces.tenant_id = #{tenant.id} AND LOWER(BTRIM(contacts.email)) = email_soft_bounces.email_address AND soft_bounce_count >= 3 )
        AND (
          (
            true
            #{location_condition}
            #{rule_conditions}
            #{exclusions_query}
            #{campaign_exclusions_query}
            #{oversend_exclusions_query}
          )
          #{inclusions_query}
        )
        #{search_query}
        GROUP BY contacts.id
        ORDER BY #{sort_query}
        #{limit}
      }
    end

    query
  end

  def account_type_query
    result = ""
    case account_type
    when "account"
      result = "AND contacts.temp = FALSE"
    when "temp"
      result = "AND contacts.temp = TRUE"
    end
    result
  end

  def tenant_count(tenant)
    counts.find_by(tenant_id: tenant.id).try(:total_count) || 0
  end

  def enterprise_count(selected_tenants)
    ContactListCount.where(tenant_id: selected_tenants, contact_list_id: id).sum(:total_count)
  end

  def contextuals(tenant, contacts = nil)
    contacts ||= all_contacts(tenant, -1)
    result = {}
    rules.order(id: :asc).each do |rule|
      contextuals = rule.get_rule_contextuals(tenant, contacts)
      contextuals.each do |contact_id, value|
        result[contact_id] = {} unless result[contact_id]
        result[contact_id].merge!(value) { |key, first, second| (first << second) }
      end
    end
    result
  end

  def exported_csv(tenant, with_headers = true)
    current_locale = I18n.locale
    I18n.locale = tenant.enterprise.locale
    contacts = all_contacts(tenant, -1)
    contextuals = contextuals(tenant, contacts)
    result = CSV.generate(col_sep: tenant.enterprise.csv_col_sep) do |csv|
      fields = %w[
        first_name
        last_name
        email
        phone
        mobile
        sales_rep_name
        sales_rep_email
        company_name
        printspeak_contact_url
        printspeak_company_url
        tenant_name
        tenant_phone
        tenant_contact_name
        tenant_number
        tenant_address_1
        tenant_address_2
        tenant_city
        tenant_state
        tenant_zip
        address_name
        street1
        street2
        city
        zip
        state
        company_address_name
        company_street1
        company_street2
        company_city
        company_zip
        company_state
      ]
      fields << "location" if tenant.sales_rep_for_locations
      fields = fields + contextuals.first[1].keys if contextuals.count > 0
      csv << fields.map { |f| I18n.t_prefix(f, tenant) } if with_headers


      company_ids = contacts.map do |contact|
        contact.company_id if !contact.company_id.nil?
      end
      company_ids = company_ids.try(:compact).try(:uniq)

      contact_companies = {}
      if company_ids && company_ids.count > 0
        Company.where(id: company_ids).each do |company|
          contact_companies.store(company.id, company)
        end
      end

      contact_url = Rails.application.routes.url_helpers.contact_url("")
      company_url = Rails.application.routes.url_helpers.company_url("")

      contacts.each do |contact|
        company = contact_companies[contact.company_id] if contact.company_id
        sales_rep = contact.sales_rep
        sales_rep = SalesRep.where(tenant: tenant).where(platform_id: company.sales_rep_platform_id).first if sales_rep.nil? && !company.nil?
        sales_rep_name = sales_rep.try(:user).try(:full_name)
        sales_rep_email = sales_rep.try(:user).try(:email)
        contact_address = contact.try(:address)
        company_address = contact.try(:company).try(:invoice_address)
        values = [
          contact.first_name.try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : contact.first_name.try(:strip).try(:gsub, /[\r|\n]/, ""),
          contact.last_name.try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : contact.last_name.try(:strip).try(:gsub, /[\r|\n]/, ""),
          contact.email.try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : contact.email.try(:strip).try(:gsub, /[\r|\n]/, ""),
          contact.phone.try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : contact.phone.try(:strip).try(:gsub, /[\r|\n]/, ""),
          contact.mobile.try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : contact.mobile.try(:strip).try(:gsub, /[\r|\n]/, ""),
          sales_rep_name.try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : sales_rep_name.try(:strip).try(:gsub, /[\r|\n]/, ""),
          sales_rep_email.try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : sales_rep_email.try(:strip).try(:gsub, /[\r|\n]/, ""),
          company.try(:name).try(:strip).try(:gsub, /[\r|\n]/, ""),
          "#{contact_url}#{contact.id}",
          company.nil? ? nil : "#{company_url}#{company.id}",
          tenant.name,
          tenant.phone,
          tenant.contact_name,
          tenant.number,
          tenant.address_1,
          tenant.address_2,
          tenant.suburb,
          tenant.state,
          tenant.postcode,
          contact_address.try(:name).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : contact_address.try(:name).try(:strip).try(:gsub, /[\r|\n]/, ""),
          contact_address.try(:street1).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : contact_address.try(:street1).try(:strip).try(:gsub, /[\r|\n]/, ""),
          contact_address.try(:street2).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : contact_address.try(:street2).try(:strip).try(:gsub, /[\r|\n]/, ""),
          contact_address.try(:city).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : contact_address.try(:city).try(:strip).try(:gsub, /[\r|\n]/, ""),
          contact_address.try(:zip).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : contact_address.try(:zip).try(:strip).try(:gsub, /[\r|\n]/, ""),
          contact_address.try(:state).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : contact_address.try(:state).try(:strip).try(:gsub, /[\r|\n]/, ""),
          company_address.try(:name).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : company_address.try(:name).try(:strip).try(:gsub, /[\r|\n]/, ""),
          company_address.try(:street1).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : company_address.try(:street1).try(:strip).try(:gsub, /[\r|\n]/, ""),
          company_address.try(:street2).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : company_address.try(:street2).try(:strip).try(:gsub, /[\r|\n]/, ""),
          company_address.try(:city).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : company_address.try(:city).try(:strip).try(:gsub, /[\r|\n]/, ""),
          company_address.try(:zip).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : company_address.try(:zip).try(:strip).try(:gsub, /[\r|\n]/, ""),
          company_address.try(:state).try(:strip).try(:gsub, /[\r|\n]/, "").blank? ? nil : company_address.try(:state).try(:strip).try(:gsub, /[\r|\n]/, "")
        ]
        values << (contact.location.nil? ? "No Location" : contact.location.name) if tenant.sales_rep_for_locations
        if contextuals.count > 0
          contextuals[contact.id].each do |key, value|
            values << value.join(" ")
          end
        end
        csv << values
      end
    end
    I18n.locale = current_locale
    result
  end

  def create_export_job(target_tenant, target_user, target_ids, combined = false)
    filename = "#{name.squish.tr(' ' , '_')}"
    if target_ids.count == 1
      first_tenant = Tenant.enabled.where(id: target_ids, enterprise_id: target_tenant.enterprise_id).first
      if first_tenant
        filename = "#{PrintSpeak::Application.to_file_system_name(first_tenant.name)}_#{PrintSpeak::Application.to_file_system_name(name)}"
        filename = "#{PrintSpeak::Application.to_file_system_name(first_tenant.number)}_#{filename}" if RegionConfig.require_value("region") == "us"
      end
    end
    job = BackgroundJob.queue(
      tenant: target_tenant,
      user: target_user,
      job_type: "contact_list_export",
      name: "Contact List Export Status",
      description: "Exporting contact list",
      status_view: "contact_lists/export_status",
      completed_view: "contact_lists/export_status",
      data: {
        selected_ids: target_ids,
        combined: combined,
        contact_list_id: id,
        filename: filename,
      }
    )
    job
  end

  def self.do_export_job(job)
    require "zip"
    bom = "\xEF\xBB\xBF"  # Defines UTF-8 ByteOrderMark to csv so Excel is happy
    data = job.data
    out_data = String.new
    error = String.new
    filename = data["filename"]

    contact_list = ContactList.where(id: data["contact_list_id"]).first
    selected_ids = data["selected_ids"] || []
    mime_type = "text/csv"
    if contact_list && selected_ids.count > 0
      target_tenants = Tenant.enabled.where(id: selected_ids, enterprise_id: job.tenant.enterprise_id).order(name: :asc)
      if target_tenants.count > 1 && !data["combined"]
        mime_type = "application/zip"
        filename << ".zip"
        out_data = Zip::OutputStream.write_buffer do |out|
          target_tenants.each do |tenant|
            tenant_filename = "#{tenant.name.squish.tr(' ' , '_')}_#{name.squish.tr(' ' , '_')}.csv"
            tenant_filename = "#{tenant.number.squish.tr(' ' , '_')}_#{tenant_filename}" if RegionConfig.require_value("region") == "us"
            out.put_next_entry(tenant_filename.tr("/" , "_").tr("\\" , "_"))
            out.write(bom)
            out.write(contact_list.exported_csv(tenant))
          end
        end.string
      else
        filename << ".csv"
        out_data << bom
        first = true
        target_tenants.each do |tenant|
          out_data << contact_list.exported_csv(tenant, first)
          first = false
        end
      end
    else
      error = "Tenant not found!" if selected_ids.count == 0
      error = "Contact list not found!" if !contact_list
    end

    fresh_job = BackgroundJob.where(id: job.id).first
    if fresh_job && !fresh_job.data["send_email"].blank?
      begin
        if error.blank?
          target_user = User.where(id: data["user_id"]).first
          if target_user
            attachment = Asset.new(tenant_id: fresh_job.tenant.id,
                                   enterprise_id: fresh_job.tenant.enterprise_id,
                                   category: "ContactListExport",
                                   new_file_contents: out_data,
                                   new_file_name: filename,
                                   context_type: "ContactList",
                                   context_id: contact_list.id)

            attachment.save

            Email.ses_send([fresh_job.data["send_email"]],
                          "Print Speak - Contact List Export - #{contact_list.name}",
                          Emails::Task.new.new_contact_list_export(contact_list, target_user, attachment.presigned_url(false, 259200)))
          end
        end
      rescue StandardError => e
        Honeybadger.notify(
          error_class: "Contact List Export Send Fail",
          error_message: e.message,
          backtrace: e.backtrace
        )
      end
    end

    {
      error: error,
      mime: mime_type,
      data: Base64.encode64(out_data),
      lifespan: 1.hour
    }
  end

  def modifiable(target_tenant, user)
    (!global && target_tenant.id == tenant_id) || (user.is_enterprise_user? && user.enterprise_id == enterprise_id)
  end
end
