class Unsubscribe < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :contact

  # CREATE INDEX CONCURRENTLY index_unsubscribes_tenant_contact_type_email_fixed ON unsubscribes(tenant_id, contact_id, unsub_type, email, LOWER(TRIM(email)), fixed) WHERE fixed = FALSE;
  # CREATE INDEX CONCURRENTLY index_unsubscribes_tenant_contact_type_email_not_fixed ON unsubscribes(tenant_id, contact_id, unsub_type, email, LOWER(TRIM(email)), fixed) WHERE fixed = TRUE;
  # CREATE INDEX CONCURRENTLY index_contacts_tenant_not_unsubbed ON contacts (tenant_id) WHERE temp = FALSE AND deleted = FALSE AND unsubscribed = FALSE;
  # CREATE INDEX CONCURRENTLY index_contacts_tenant_not_unsubbed_with_email ON contacts (tenant_id, id, rolling_12_month_sales DESC NULLS LAST, first_name, company_id, deleted, email, temp, unsubscribed) WHERE temp = FALSE AND deleted = FALSE AND unsubscribed = FALSE AND email ~~ '%@%';
  # CREATE INDEX CONCURRENTLY index_contacts_company_sales_name_not_unsubbed ON contacts (tenant_id, company_id, rolling_12_month_sales DESC NULLS LAST, first_name, temp, deleted, unsubscribed, id) WHERE temp = FALSE AND deleted = FALSE AND unsubscribed = FALSE;
  # CREATE INDEX CONCURRENTLY index_contacts_email_validations_not_unsubbed ON contacts (tenant_id, needs_email_validation, company_id, tenant_id, unsubscribed, deleted, temp) WHERE deleted = FALSE AND unsubscribed = FALSE;
  # CREATE INDEX CONCURRENTLY index_contacts_tenant_unsubbed ON contacts (tenant_id, unsubscribed, id) WHERE unsubscribed = TRUE;
  # CREATE INDEX CONCURRENTLY index_contacts_tenant_deleted_stats ON contacts (tenant_id, deleted, id, email, company_id, latest_order_date, source_created_at, unsubscribed);

  def propagate(data={})
    contacts = tenant.contacts_matching_email(email)
    contacts.each do |contact|
      next if contact.id == contact_id
      contact.unsubscribe(unsub_type, data: data, propagate: false)
    end
  end

  def fix(new_email, current_user)
    contact_ids = []
    if Unsubscribe.definitions[unsub_type][:propagates] == true
      unsubs = matching_unsubscribes
      unsubs.each do |unsub|
        unsub.fixed = true
        unsub.fixed_by_user_id = current_user.try(:id) || 0
        unsub.save
        contact_ids << unsub.contact_id
      end
    else
      self.fixed = true
      self.fixed_by_user_id = current_user.try(:id) || 0
      save
      contact_ids << contact_id
    end

    if contact_ids.count > 0
      if unsub_type == "soft_bounce" || unsub_type == "hard_bounce"
        campaign_message_ids = CampaignMessage.where(contact_id: contact_ids, sent: true, failed: true, fixed: false).pluck(:id)
        if campaign_message_ids.count > 0
          CampaignMessage.where(id: campaign_message_ids).update_all(fixed: true)
          CampaignMessage.where(parent_message_id: campaign_message_ids).update_all(fixed: true)
        end
      elsif unsub_type.start_with?("validation_")
        EmailValidation.where(contact_id: contact_ids, fixed: false).update_all(fixed: true)
      end

      unsubbed_contact_ids = Unsubscribe.where(tenant_id: tenant_id, contact_id: contact_ids, fixed: false).pluck(:contact_id)
      cleared_contact_ids = contact_ids - unsubbed_contact_ids
      if cleared_contact_ids.count > 0
        cleared_contacts = Contact.where(id: cleared_contact_ids, tenant_id: tenant.id)
        cleared_contacts.each do |cleared_contact|
          cleared_contact.unsubscribed = false
          cleared_contact.remote_update_required = TRUE
          if Unsubscribe.definitions[unsub_type][:fixable] == :reverify
            cleared_contact.needs_email_validation = true
            cleared_contact.email_validation_attempts = -1
          end
          cleared_contact.save
        end
      end
    end
  end

  def matching_unsubscribes
    clean_email = Email.clean_email(email)

    result = Unsubscribe.none
    if !clean_email.blank?
      result = Unsubscribe.where(tenant_id: tenant_id, unsub_type: unsub_type, fixed: false).where("LOWER(TRIM(unsubscribes.email)) = ?", clean_email)
    end

    result
  end

  def self.email_address(tenant, email_address, type, data: {})
    if Unsubscribe.definitions[type][:propagates] == false
      raise "Unsubscribe by email is only allowed for types that should propagate"
    end
    contact = tenant.contacts_matching_email(email_address).first
    if contact
      contact.unsubscribe(type, data: data)
    end
  end

  def self.on_suppression_list?(tenant, email_address)
    result = false

    unsub = Unsubscribe.where(tenant_id: tenant.id, unsub_type: "suppression_list", email: Email.clean_email(email_address)).first
    if unsub
      result = true
    end

    result
  end

  def self.definitions
    result = {
      "soft_bounce" => {
        name: "Soft Bounced",
        desc: "This email address has soft bounced 3 times",
        fixable: :reverify,
        propagates: true
      },
      "hard_bounce" => {
        name: "Hard Bounced",
        desc: "This email address has hard bounced",
        fixable: :new_email,
        propagates: true
      },
      "bad_email" => {
        name: "Bad Email",
        desc: "A prevously used bad email was set for this contact",
        fixable: :any_email,
        propagates: false
      },
      "contact_manual" => {
        name: "PrintSpeak Do Not Mail",
        desc: "This email address is marked as do not mail by a PrintSpeak user",
        fixable: :any_email,
        propagates: false
      },
      "contact_vision" => {
        name: "Vision Do Not Mail",
        desc: "This contact is marked as do not mail in Vision",
        fixable: :any_email,
        propagates: false
      },
      "company_vision" => {
        name: "Company Do Not Mail",
        desc: "The company is marked as do not mail in Vision",
        fixable: :company,
        propagates: false
      },
      "suppression_list" => {
        name: "Suppression List",
        desc: "This email address is on a suppression list",
        fixable: :new_email,
        propagates: true
      },
      "complaint" => {
        name: "Complaint",
        desc: "A complaint was received from this email address",
        fixable: :none,
        propagates: true
      },
      "unsubscribed_none" => {
        name: "Unsubscribed",
        desc: "No reason was given",
        fixable: :none,
        propagates: true
      }
    }
    EmailValidation.undeliverable_codes.each do |code|
      fixable = :any_email
      reverify_list = %w[
        validation_email_disabled
        validation_p_email_disabled
        validation_p_unknown_email
        validation_p_relay_error
        validation_domain_error
        validation_dead_server
        validation_syntax_error
        validation_error
        validation_p_error
        validation_invalid_syntax
      ]

      if reverify_list.include?(code)
        fixable = :reverify
      end

      result["validation_#{code}"] = {
        name: "Validation Failure",
        desc: "Validation Failed: #{EmailValidation.desc(code)}",
        fixable: fixable,
        propagates: true
      }
    end
    Unsubscribe.manual_reasons.each do |code, desc|
      result["unsubscribed_#{code}"] = {
        name: "Unsubscribed",
        desc: "Unsubscribed: #{desc}",
        fixable: :none,
        propagates: true
      }
    end
    result
  end

  def self.names_with_codes(exclude_codes = [])
    merged_reasons = []

    definitions = Unsubscribe.definitions.map do |key, value|
      {name: value[:name], codes: [key]} if !exclude_codes.include?(key)
    end

    definitions.compact.each do |unsub_reason|
      found = false
      merged_reasons.each do |merged_reason|
        if merged_reason[:name] == unsub_reason[:name]
          found = true
          merged_reason[:codes] << unsub_reason[:codes].first
          break
        end
      end

      if !found
        reason = unsub_reason
        reason[:value] = unsub_reason[:name].downcase.tr(" ", "_")
        merged_reasons << reason
      end
    end
    merged_reasons
  end

  def self.manual_reasons
    {
      'not_relevant': "Content is not relevant",
      'email_too_often': "You are emailing me too often",
      'never_signed_up': "I never signed up for this email",
    }
  end
end
