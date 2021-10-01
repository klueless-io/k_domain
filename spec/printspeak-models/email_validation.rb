class EmailValidation < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :enterprise
  belongs_to :contact



  def status
    result = "unknown"

    if EmailValidation.deliverable_codes.include?(code)
      result = "deliverable"
    elsif EmailValidation.deliverable_but_unverified_codes.include?(code)
      result = "deliverable_but_unverified"
    elsif EmailValidation.unverified_codes.include?(code)
      result = "unverified"
    elsif EmailValidation.undeliverable_codes.include?(code)
      result = "undeliverable"
    end

    result
  end

  def name
    result = ""
    if code.start_with?("t_")
      result = "#{code[2..-1]} (Temporary)"
    elsif code.start_with?("p_")
      result = "#{code[2..-1]} (Permanent)"
    else
      result = code
    end
    result.titleize
  end

  def desc
    result = ""
    clean_code = code
    if clean_code.start_with?("t_") || clean_code.start_with?("p_")
      clean_code = code[2..-1]
    end
    result = EmailValidation.code_descriptions[clean_code.to_sym] || ""
    result
  end

  def self.desc(code)
    result = ""
    clean_code = code
    if clean_code.start_with?("t_") || clean_code.start_with?("p_")
      clean_code = code[2..-1]
    end
    result = EmailValidation.code_descriptions[clean_code.to_sym] || ""
    result
  end

  def color
    result = "default"
    case status
    when "deliverable"
      result = "blue"
    when "deliverable_but_unverified"
      result = "mustard"
    when "unverified"
      result = "orange"
    when "undeliverable"
      result = "red"
    end
    result
  end

  def self.code_descriptions
    {
      'ok': "The email address is verified",
      'ok_for_all': "The email server accepts all incoming mail but does not verify the specific email scanned",
      'email_exists': "The email address exists but it is unclear if delivery will succeed",
      'antispam_system': "The email server treats the incoming scan as a spam attempt and the specific email cannot be verified",
      'email_disabled': "The email account is disabled, suspended, or limited",
      'unknown_email': "The email address does not exist",
      'attempt_rejected': "The email address scan failed",
      'relay_error': "The verification attempt failed because of a relay problem",
      'domain_error': "There is a problem with the domain and no email can be delivered to that domain",
      'dead_server': "The email server cannot be contacted and no email can be delivered to that server",
      'syntax_error': "There is a syntax error in the email address being scanned",
      'error': "Server is saying that delivery was failed, but no information about email existence or availability",
      'smtp_error': "The email server returns an error and the email address cannot be verified",
      'smtp_protocol': "The email scan could connect to the email server but it rejected the verification attempt and the email cannot be verified",
      'spamtrap': "The email is a spam trap",
      'disposable': "The email is disposable",
      'invalid_syntax': "The email syntax is invalid",
      'lock': "The email address is locked",
      'unknown': "Unknown"
    }
  end

  def self.deliverable_codes
    [
      "ok"
    ]
  end

  def self.deliverable_but_unverified_codes
    %w[
      ok_for_all
      email_exists
    ]
  end

  def self.unverified_codes
    %w[
      antispam_system
      t_antispam_system
      p_antispam_system
    ]
  end

  def self.undeliverable_codes
    %w[
      email_disabled
      t_email_disabled
      p_email_disabled
      unknown_email
      t_unknown_email
      p_unknown_email
      attempt_rejected
      t_attempt_rejected
      p_attempt_rejected
      relay_error
      t_relay_error
      p_relay_error
      domain_error
      dead_server
      syntax_error
      error
      t_error
      p_error
      smtp_error
      smtp_protocol
      spamtrap
      disposable
      invalid_syntax
      unknown_email
      lock
      unknown
    ]
  end

  def self.valid_codes
    EmailValidation.deliverable_codes + EmailValidation.deliverable_but_unverified_codes + EmailValidation.unverified_codes + EmailValidation.undeliverable_codes
  end

  def self.scan_contact(contact)
    return nil if contact.nil?
    failed_validation = false
    clean_email = Email.clean_email(contact.email)
    if clean_email.blank?
      if contact.needs_email_validation
        contact.update_attributes(needs_email_validation: false)
      end
      return nil
    end

    result = nil

    if contact.needs_email_validation
      matching_contacts = Contact.joins(:company)
                          .where(companies: { marketing_do_not_mail: false })
                          .where(tenant: contact.tenant, deleted: false, unsubscribed: false, temp: false)
                          .where("LOWER(TRIM(contacts.email)) = ?", clean_email)

      api_result = nil
      if Rails.env.development?
        rand_result = "unknown"
        rand_percent = rand(100)
        if rand_percent < 10
          rand_result = EmailValidation.unverified_codes.sample
        elsif rand_percent < 30
          rand_result = EmailValidation.undeliverable_codes.sample
        elsif rand_percent < 40
          rand_result = EmailValidation.deliverable_but_unverified_codes.sample
        else
          rand_result = EmailValidation.deliverable_codes.sample
        end
        api_result = OpenStruct.new({
          code: 200,
          body: rand_result
        })
      else
        if Email.valid_format?(clean_email)
          request_start = Time.now
          begin
            api_result = RestClient.get("https://apps.emaillistverify.com/api/verifyEmail", {
              params: {
                email: clean_email,
                secret: Rails.application.secrets.email_list_verify_api_key
              }
            })
          rescue StandardError
          end
        else
          api_result = OpenStruct.new({
            code: 200,
            body: "invalid_syntax"
          })
        end
      end

      if api_result.try(:code) == 200
        result_code = api_result.body
        if result_code == "error_credit"
          raise "Email List Verify out of credits"
        end

        if result_code == "unknown" && contact.email_validation_attempts < 3
          failed_validation = true
        else
          if EmailValidation.valid_codes.include?(result_code)
            contact_ids = [contact.id]
            rescan_needed = result_code.start_with?("t_")
            email_validation = EmailValidation.create(
              tenant: contact.tenant,
              enterprise: contact.tenant.enterprise,
              contact_id: contact.id,
              address: clean_email,
              parent_id: 0,
              code: result_code,
              rescan_needed: rescan_needed,
              pending_rescan: rescan_needed
            )
            matching_contacts.each do |matching_contact|
              next if contact.id == matching_contact.id
              contact_ids << matching_contact.id
              EmailValidation.create(
                tenant: matching_contact.tenant,
                enterprise: matching_contact.tenant.enterprise,
                contact_id: matching_contact.id,
                address: clean_email,
                parent_id: email_validation.id,
                code: result_code,
                rescan_needed: rescan_needed,
                pending_rescan: rescan_needed
              )
            end
            Contact.where(id: contact_ids).update_all(needs_email_validation: false)
            if email_validation.status == "undeliverable"
              contact.unsubscribe("validation_#{result_code}")
            end
            result = email_validation
          else
            Honeybadger.notify(
              error_class: "EmailValidation",
              error_message: "EmailValidation API Data",
              parameters: {
                api_code: api_result.code,
                api_body: api_result.body,
                email: clean_email,
                contact_id: contact.id
              }
            )
            raise "EmailValidation API gave unknown result"
          end
        end
      elsif api_result.nil?
        failed_validation = true
      else
        Honeybadger.notify(
          error_class: "EmailValidation",
          error_message: "EmailValidation API Data",
          parameters: {
            api_code: api_result.code,
            api_body: api_result.body,
            email: clean_email,
            contact_id: contact.id
          }
        )
      end

      if failed_validation
        Contact.where(id: matching_contacts).update_all(email_validation_attempts: contact.email_validation_attempts + 1)
      end
    else
      result = EmailValidation.latest_result(contact)
    end

    result
  end

  def self.latest_result(contact)
    return nil if contact.nil?
    EmailValidation.where(tenant: contact.tenant, contact: contact).order(created_at: :desc).first
  end

  def self.do_scan(tenant, limit: 10)
    return nil if tenant.nil?
    while limit > 0
      contacts = Contact.joins(:company).where(companies: { marketing_do_not_mail: false }).where(tenant: tenant, needs_email_validation: true, deleted: false, unsubscribed: false, temp: false).order("contacts.email_validation_attempts ASC, contacts.source_created_at DESC NULLS LAST").limit(limit)
      limit = 0
      address_list = []
      contacts.each do |contact|
        clean_email = Email.clean_email(contact.email)
        next if address_list.include?(clean_email)
        if clean_email.blank?
          limit += 1
        else
          address_list << contact.email
        end
        EmailValidation.scan_contact(contact)
      end
    end
    nil
  end

  def self.result_query(tenant: nil, page: 1, per: 10, sort: "date", sort_order: "desc", deliverable: false, deliverable_but_unverified: false, unverified: false, undeliverable: false, search: nil)
    sort = "date" if !%w[date name email code].include?(sort)
    sort_order = "desc" if !%w[asc desc].include?(sort_order)
    order_query = ""
    case sort
    when "date"
      order_query = "T.created_at #{sort_order}"
    when "name"
      order_query = "contacts.first_name #{sort_order}"
    when "email"
      order_query = "contacts.email #{sort_order}"
    when "code"
      order_query = "T.code #{sort_order}"
    end

    search_condition = nil
    if !search.blank?
      search_condition = %Q{
        AND (
          (trim(regexp_replace(COALESCE(contacts.first_name, '') || ' ' || COALESCE(contacts.last_name, ''), '\s+', ' ', 'g')) ILIKE #{ActiveRecord::Base::sanitize("%#{search}%")})
          OR contacts.email ILIKE #{ActiveRecord::Base::sanitize("%#{search}%")}
          OR companies.name ILIKE #{ActiveRecord::Base::sanitize("%#{search}%")}
        )
      }
    end

    conditions = ""
    if !tenant.nil?
      conditions << " AND tenant_id = #{tenant.id}"
    end
    if deliverable
      conditions << " AND code IN (#{EmailValidation.deliverable_codes.map { |s| "'#{s}'" }.to_csv})"
    end
    if deliverable_but_unverified
      conditions << " AND code IN (#{EmailValidation.deliverable_but_unverified_codes.map { |s| "'#{s}'" }.to_csv})"
    end
    if unverified
      conditions << " AND code IN (#{EmailValidation.unverified_codes.map { |s| "'#{s}'" }.to_csv})"
    end
    if undeliverable
      conditions << " AND code IN (#{EmailValidation.undeliverable_codes.map { |s| "'#{s}'" }.to_csv})"
    end

    query = %Q{
      SELECT T.*, (COUNT(*) OVER()) AS total_count
      FROM (
        SELECT *, ROW_NUMBER() OVER(PARTITION BY email_validations.contact_id ORDER BY email_validations.created_at DESC) AS row_num
        FROM email_validations
        WHERE TRUE
        #{conditions}
      ) T
      INNER JOIN contacts ON contacts.id = T.contact_id
      INNER JOIN companies ON companies.id = contacts.company_id
      WHERE T.row_num = 1
      #{search_condition}
      ORDER BY #{order_query}
      LIMIT #{per}
      OFFSET #{(page-1) * per}
    }

    results = EmailValidation.find_by_sql(query)
    Kaminari.paginate_array(results, total_count: results.first.try(:total_count) || 0).page(page).per(per)
  end
end
