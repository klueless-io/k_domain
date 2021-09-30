class EmailMessage < ActiveRecord::Base
  self.table_name = "messages"
  self.primary_key = "id"

  establish_connection "mail_#{Rails.env}".to_sym


  has_and_belongs_to_many :email_labels, -> { uniq }
  has_many :email_attachments
  belongs_to :email_inbox

  alias_attribute :inbox, :email_inbox
  alias_attribute :labels, :email_labels

  attr_accessor :failed
  attr_accessor :sent_id

  def decoded_text
    body = ""
    body = text.force_encoding(Encoding::UTF_8) unless text.blank?
    body
  end

  def decoded_html(with_attachments = true, inline_only = false)
    body = ""
    body = html.force_encoding(Encoding::UTF_8) unless html.blank?
    body = "<pre>#{decoded_text}</pre>" if body.blank?
    body = decode_attachments(body, inline_only) if with_attachments
    body = body.sub(/<img src="https?:\/\/[a-z0-9\.:]+?\/tracker\/[a-z0-9]+?"\/>/i, "")
    body
  end

  def decode_attachments(body, inline_only = false)
    if !attachments["inline"].nil?
      attachments["inline"].each do |attachment|
        sources = body.scan(/<img[^>]+src=[\'"]?(cid:#{Regexp.quote(attachment['file_name'])})[\'"]?.+>/im)
        sources.each do |source|
          body = body.sub(source.first, "/emails/attachment/#{id}/#{attachment['part_id']}")
        end
      end
    end

    if !attachments["full"].nil?
      attachments["full"].each do |attachment|
        sources = body.scan(/<img[^>]+src=[\'"]?(cid:#{Regexp.quote(attachment['file_name'])})[\'"]?.+>/im)
        sources.each do |source|
          body = body.sub(source.first, "/emails/attachment/#{id}/#{attachment['part_id']}")
        end
      end
    end
    body
  end

  # def thread_count
  #   result = 1
    # if self.id
    #   context_query = ""
    #   if !self.estimate_ids.nil? && self.estimate_ids.count > 0
    #     context_query = "AND ARRAY[#{self.estimate_ids.first}] <@ messages.estimate_ids"
    #   elsif !self.invoice_ids.nil? && self.invoice_ids.count > 0
    #     context_query = "AND ARRAY[#{self.invoice_ids.first}] <@ messages.invoice_ids"
    #   elsif !self.company_ids.nil? && self.company_ids.count > 0
    #     context_query = "AND ARRAY[#{self.company_ids.first}] <@ messages.company_ids"
    #   end
    #   query = %Q{
    #     SELECT COUNT (*) AS thread_message_count
    #     FROM (
    #       SELECT *
    #       FROM messages
    #       WHERE (ARRAY[(SELECT address FROM inboxes WHERE id = messages.inbox_id)] <@ messages.from_addresses OR ARRAY[(SELECT address FROM inboxes WHERE id = messages.inbox_id)] <@ messages.to_addresses)
    #       #{context_query}
    #     ) messages
    #     WHERE messages.inbox_id = #{self.inbox_id}
    #     AND (ARRAY ['#{self.message_id}'] <@messages.message_id_references OR messages.id = #{self.id})
    #   }
    #   result = EmailMessage.find_by_sql(query).try(:first).try(:thread_message_count) || 1
    # end
  #   result
  # end

  def self.thread_count(tenant, email_message, selected_addresses = nil, blacklist_query = nil)
    return 0 if email_message.nil?
    1
    # return 1 if !email_message.id
    # result = 1
    # if email_message.id
    #   context_query = ""
    #   if !email_message.estimate_ids.nil? && email_message.estimate_ids.count > 0
    #     context_query = "AND ARRAY[#{email_message.estimate_ids.first}] && messages.estimate_ids"
    #   elsif !email_message.invoice_ids.nil? && email_message.invoice_ids.count > 0
    #     context_query = "AND ARRAY[#{email_message.invoice_ids.first}] && messages.invoice_ids"
    #   elsif !email_message.company_ids.nil? && email_message.company_ids.count > 0
    #     context_query = "AND ARRAY[#{email_message.company_ids.first}] && messages.company_ids"
    #   end

    #   selected_addresses = EmailMessage.selected_addresses(tenant) if selected_addresses.nil?
    #   blacklist_query = EmailMessage.blacklist_query(tenant) if blacklist_query.nil?

    #   query = %Q{
    #     SELECT COUNT(*) AS thread_message_count
    #     FROM (
    #       SELECT *
    #       FROM messages
    #       WHERE (ARRAY[#{selected_addresses}] && messages.from_addresses OR ARRAY[#{selected_addresses}] && messages.to_addresses)
    #       #{context_query}
    #       #{blacklist_query}
    #     ) messages
    #     WHERE messages.inbox_id = #{email_message.inbox_id}
    #     AND (ARRAY [md5('#{email_message.message_id}')] && messages.message_id_reference_hashes OR messages.id = #{email_message.id})
    #   }
    #   result = EmailMessage.find_by_sql(query).try(:first).try(:thread_message_count) || 1
    # end
    # result
  end

  def self.thread_emails(tenant, email_message)
    result = [email_message]
    if email_message.id
      context_query = ""
      if !email_message.company_ids.nil? && email_message.company_ids.count > 0
        context_query = "AND ARRAY[#{email_message.company_ids.first}] && messages.company_ids"
      end

      selected_addresses = EmailMessage.selected_addresses(tenant)

      query = %Q{
        SELECT *
        FROM (
          SELECT *
          FROM messages
          WHERE (ARRAY[#{selected_addresses}] && messages.from_addresses OR ARRAY[#{selected_addresses}] && messages.to_addresses)
          #{context_query}
          #{EmailMessage.blacklist_query(tenant)}
        ) messages
        WHERE messages.inbox_id = #{email_message.inbox_id}
        AND (ARRAY[md5('#{email_message.message_id}')] && messages.message_id_reference_hashes OR messages.id = #{email_message.id})
        ORDER BY messages.date DESC NULLS LAST
      }
      result = EmailMessage.find_by_sql(query)
    end
    result
  end

  def self.search(tenant, context, search_names: nil, search_emails: nil, search_subject: nil, search_body: nil, page: 1, per: 10)
    return Kaminari.paginate_array([]).page(page).per(per) if context.class == Shipment

    base_class = context.class
    context_class = [context.class]
    context_column = context.class.to_s.downcase
    if [Sale, Order, Invoice].include?(context.class)
      base_class = Invoice
      context_class = [Invoice, Sale, Order]
      context_column = "invoice"
    end

    contacts = []

    if base_class == Contact
      contacts = [context]
    elsif base_class == Company
      contacts = Contact.where(tenant_id: tenant.id, company_id: context.id)
    end

    user_addresses = EmailInbox.user_mapped_addresses
    skipped_contact_ids = []
    if !user_addresses.nil?
      contacts.each do |contact|
        if !contact.email.blank? && user_addresses.include?(contact.email)
          skipped_contact_ids << contact.id
        end
      end
    end

    contact_id_skip_query = ""
    if skipped_contact_ids.count > 0
      contact_id_skip_query = %Q{
        AND (
          NOT ARRAY[#{skipped_contact_ids.join(',')}] && COALESCE(messages.contact_ids, ARRAY[]::int4[])
          OR (
            array_length(messages.invoice_ids, 1) > 0 OR array_length(messages.estimate_ids, 1) > 0 OR array_length(messages.inquiry_ids, 1) > 0 OR length(internal_message_id) > 1
          )
        )
      }
    end

    selected_addresses = EmailMessage.selected_addresses(tenant)

    skipped_inbox_ids = []
    EmailInbox.enterprise_inboxes.each do |inbox|
      skipped_inbox_ids << inbox.id
    end

    inbox_id_skip_query = ""
    if skipped_inbox_ids.count > 0
      inbox_id_skip_query = %Q{
        AND messages.inbox_id NOT IN (#{skipped_inbox_ids.join(',')})
      }
    end

    search_query = ""
    search_queries = []
    if !search_subject.blank?
      search_queries << " messages.subject ILIKE #{ActiveRecord::Base::sanitize("%#{search_names}%")}"
    end
    if !search_names.blank?
      search_queries << "array_to_string(messages.from_names, ' ') ILIKE #{ActiveRecord::Base::sanitize("%#{search_names}%")} OR array_to_string(messages.to_names, ' ') ILIKE #{ActiveRecord::Base::sanitize("%#{search_names}%")}"
      search_queries << "array_to_string(messages.to_names, ' ') ILIKE #{ActiveRecord::Base::sanitize("%#{search_names}%")}"
    end
    if !search_emails.blank?
      search_queries << "array_to_string(messages.from_addresses, ' ') ILIKE #{ActiveRecord::Base::sanitize("%#{search_emails}%")} OR array_to_string(messages.to_addresses, ' ') ILIKE #{ActiveRecord::Base::sanitize("%#{search_emails}%")}"
      search_queries << "array_to_string(messages.to_addresses, ' ') ILIKE #{ActiveRecord::Base::sanitize("%#{search_emails}%")}"
    end
    if search_queries.count > 0
      search_query << "AND ("
      search_queries.each_with_index do |search, index|
        search_query << " OR " if index > 0
        search_query << search
      end
      search_query << ")"
    end

    sent_email_conditions = %Q{
      (
        emails.context_id = #{ActiveRecord::Base::sanitize(context.id)}
        AND emails.context_type IN (#{context_class.map { |s| "'#{s}'" }.to_csv})
      )
    }

    if %w[estimate invoice].include?(context_column) && context.inquiry
      sent_email_conditions << %Q{
        OR
        (
          emails.context_id = #{ActiveRecord::Base::sanitize(context.inquiry.id)}
          AND emails.context_type = 'Inquiry'
        )
      }
    end

    if context_column == "invoice" && context.source_estimate
      sent_email_conditions << %Q{
        OR
        (
          emails.context_id = #{ActiveRecord::Base::sanitize(context.source_estimate.id)}
          AND emails.context_type = 'Estimate'
        )
      }
      if context.source_estimate.inquiry
        sent_email_conditions << %Q{
          OR
          (
            emails.context_id = #{ActiveRecord::Base::sanitize(context.source_estimate.inquiry.id)}
            AND emails.context_type = 'Inquiry'
          )
        }
      end
    end

    sent_emails = Email.where(sent_email_conditions).order(created_at: :desc).to_a
    sent_message_ids = sent_emails.map { |i| i.message_id if !i.message_id.blank? }.compact

    context_condition = "ARRAY[#{context.id}] && messages.#{context_column}_ids"

    inquiry_ids = []
    if context_column == "estimate"
      if context.inquiry
        inquiry_ids << context.inquiry.id
      end
    elsif context_column == "invoice"
      if context.inquiry
        inquiry_ids << context.inquiry.id
      end
      if context.source_estimate
        context_condition += " OR ARRAY[#{context.source_estimate.id}] && messages.estimate_ids"
        if context.source_estimate.inquiry
          inquiry_ids << context.source_estimate.inquiry.id
        end
      end
    end

    inquiry_ids = inquiry_ids.uniq

    if inquiry_ids.count > 0
      context_condition += " OR ARRAY[#{inquiry_ids.to_csv}] && messages.inquiry_ids"
    end

    query = %Q{
      SELECT messages.id, messages.inbox_id, messages.subject, messages.from_names, messages.from_addresses, messages.to_names, messages.to_addresses, messages.cc_names, messages.cc_addresses, messages.bcc_names, messages.bcc_addresses, messages.reply_to_names, messages.reply_to_addresses, messages.date, messages.message_id, messages.in_reply_to, messages.message_id_references, messages.attachments, messages.labels, messages.platform_data, messages.contact_ids, messages.company_ids, messages.estimate_ids, messages.invoice_ids, messages.internal_message_id
      FROM messages
      WHERE in_reply_to = ''
      AND (ARRAY[#{selected_addresses}] && messages.from_addresses OR ARRAY[#{selected_addresses}] && messages.to_addresses)
      AND (#{context_condition})
      #{contact_id_skip_query}
      #{EmailMessage.blacklist_query(tenant)}
      #{inbox_id_skip_query}
      #{search_query}
      ORDER BY messages.date DESC NULLS LAST
    }

    raw_synced_emails = EmailMessage.find_by_sql(query).to_a

    synced_emails = []
    synced_message_ids = []
    raw_synced_emails.each do |synced_email|
      if !synced_message_ids.include?(synced_email.message_id)
        synced_message_ids << synced_email.message_id
        synced_emails << synced_email
      end
    end

    sent_emails.each do |sent_email|
      found = false
      synced_emails.each do |synced_email|
        if (sent_email.subject == synced_email.subject && sent_email.to == synced_email.to_addresses.try(:[], 0) && sent_email.created_at.round(0) == synced_email.date.round(0)) || (!sent_email.try(:message_id).blank? && (sent_email.try(:message_id) == synced_email.message_id || sent_email.try(:message_id) == synced_email.internal_message_id)) || (!sent_email.try(:email_id).blank? && sent_email.try(:email_id) == synced_email.platform_data["gmail_message_id"])
          found = true
          break
        end
      end
      if !found
        synced_emails << sent_email.to_email_message
      end
    end

    synced_emails.sort! { |a, b| b.date <=> a.date }

    result = Kaminari.paginate_array(synced_emails).page(page).per(per)
  end

  def self.selected_addresses(tenant)
    blacklist = tenant.email_blacklist.blank? ? [] : tenant.email_blacklist.lines.map { |address| Email.clean_email(address) }
    user_ids = tenant.users.where(hide: false).where.not(role: ["Super User", "Enterprise User"]).pluck(:id)
    user_aliases = EmailAlias.where(user_id: user_ids).pluck(:email)
    user_aliases = user_aliases.map { |address| Email.clean_email(address) }
    user_aliases = user_aliases.compact.reject { |address| address.blank? || blacklist.include?(address) || (!address.split("@").second.nil? && blacklist.include?(address.split("@").second)) }
    user_aliases = user_aliases.map { |address| ActiveRecord::Base::sanitize(address) }

    selected_addresses = "(SELECT address FROM inboxes WHERE id = messages.inbox_id)"
    selected_addresses << ",#{user_aliases.to_csv}" if user_aliases.count > 0

    selected_addresses
  end

  def self.blacklist_query(tenant)
    blacklist_query = ""

    blacklist_addresses = tenant.address_blacklist
    if blacklist_addresses.count > 0
      query_safe_addresses = blacklist_addresses.map { |address| ActiveRecord::Base::sanitize(address) }.join(",")
      blacklist_query << %Q{
        AND NOT ARRAY[#{query_safe_addresses}] && COALESCE(messages.to_addresses, ARRAY[]::text[])
        AND NOT ARRAY[#{query_safe_addresses}] && COALESCE(messages.from_addresses, ARRAY[]::text[])
        AND NOT ARRAY[#{query_safe_addresses}] && COALESCE(messages.cc_addresses, ARRAY[]::text[])
      }
    end

    blacklist_domains = tenant.domain_blacklist
    if blacklist_domains.count > 0
      query_safe_domains = blacklist_domains.map { |domain| ActiveRecord::Base::sanitize(domain) }.join(",")
      blacklist_query << %Q{
        AND NOT ARRAY[#{query_safe_domains}] && COALESCE(messages.domains, ARRAY[]::text[])
      }
    end

    blacklist_query
  end
end
