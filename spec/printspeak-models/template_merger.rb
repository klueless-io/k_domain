class TemplateMerger
  require "erb"
  require "uri"
  include ERB::Util

  def initialize(*objects)
    @primary_object = objects.first
    @template = @primary_object.try(:email_template)
    @objects = objects
    @draft = false
    @nested = Array.new
    @custom = {}
    @nested_count = 0
    @include_roboto = false
  end

  def set_template(template)
    @template = template
  end

  def set_custom(custom)
    @custom = custom
  end

  def set_tracker(tracker)
    @tracker = tracker
  end

  def translations(*symbols)
    return @translations if !@translations.nil?
    result = Hash.new

    result.merge!(generic_translations) if symbols.length == 0 || symbols.include?(:generic)

    @objects.each do |object|
      method_symbol = "#{object.try(:class).try(:name)}_translations".downcase.to_sym
      object_translations = method(method_symbol) if respond_to?(method_symbol, true)

      hash = Hash.new
      hash = object_translations.call(object) if object_translations

      if symbols.length > 0
        result.merge!(hash) if symbols.include?("#{object.try(:class).try(:name)}".downcase.to_sym)
      else
        result.merge!(hash)
      end
    end

    if @template && !@draft
      tenant = get_object(:tenant)
      hash = Hash.new

      template_fields = @template.email_template_fields if @template.class == EmailTemplate
      # template_fields = @template.sms_template_fields if @template.class == SmsTemplate

      if @template.class == EmailTemplate
        template_fields.each do |field|
          hash[field.name] = field.get_value(@primary_object, tenant.try(:id))
        end
      end
      result.merge!(hash)
    end
    @translations = result

    result
  end

  def untranslated_merge(template)
    template = @template.body.gsub("{{body}}", template) if @template.try(:shell)
    result = template

    if @template && @template.wrapper && !@nested.include?(@template.wrapper.id)
      @nested << @template.wrapper.id
      @template = @template.wrapper
      result = untranslated_merge(result)
    end

    result
  end

  def translated_subject(template, draft = false)
    translated(template, draft)
  end

  def translated_body(template, draft = false)
    template = @template.body.gsub("{{body}}", template) if @template.try(:shell)
    result = translated(template, draft)
    @include_roboto = true if @template.try(:use_roboto)

    if !draft && @template && @template.wrapper && !@nested.include?(@template.wrapper.id)

      @nested << @template.wrapper.id
      @template = @template.wrapper
      @nested_count = @nested_count + 1
      result = translated_body(result, false)
      @nested_count = @nested_count - 1

    end

    result = "#{escape_content(include_roboto_font)} \n #{result}" if @nested_count == 0 && @include_roboto == true
    result
  end

  def preview_subject(template, draft = false)
    preview(template, draft)
  end

  def preview_body(template, draft = false)
    template = @template.body.gsub("{{body}}", template) if @template.try(:shell)
    result = preview(template, draft)
    @include_roboto = true if @template.try(:use_roboto)

    if !draft && @template && @template.wrapper && !@nested.include?(@template.wrapper.id)
      @nested << @template.wrapper.id
      @template = @template.wrapper
      @nested_count = @nested_count + 1
      result = preview_body(result, false)
      @nested_count = @nested_count - 1
    end

    result = "#{escape_content(include_roboto_font)} \n #{result}" if @nested_count == 0 && @include_roboto == true
    result
  end

  def self.invalid_merge_fields(text)
    text.scan(/\{\{.+?\}\}/i)
  end

  private

  def translated(template, draft = false)
    @draft = draft
    template = escape_content(template)
    translations.each do |k, v|
      value = v
      value = v.call if v.is_a?(Proc)
      template = template.gsub("{{#{k}}}", escape_content(value))
    end
    template = modifiers(template) unless draft
    template
  end

  def preview(template, draft = false)
    @draft = draft
    template = escape_content(template)

    translations.each do |k, v|
      value = v
      value = v.call if v.is_a?(Proc)
      value = escape_content(value)
      value = "[#{k.titleize}]" unless value != ""
      template = template.gsub("{{#{k}}}", value)
    end

    template = modifiers(template) unless draft
    template
  end

  def modifiers(template)
    template.scan(/(\[([^\[]*?),\s?fallback\s?=\s?([^\}]*?)\])/i,) do |match|
      if match[1].empty?
        template = template.sub(match[0], match[2])
      else
        template = template.sub(match[0], match[1])
      end
    end

    template.scan(/(\[([^\[]*?),\s?percent\s?=\s?([^\}]*?)\])/i,) do |match|
      if float?(match[1]) && float?(match[2])
        percent = match[2].to_f / 100.0
        value = match[1].to_f * percent
        template = template.sub(match[0], value.to_i.to_s)
      else
        template = template.sub(match[0], match[1])
      end
    end

    template.scan(/(\[([^\[]*?),\s?url_encode\s?([^\}]*?)\])/i,) do |match|
      if !match[1].blank?
        decoded_string = URI.decode(match[1])
        encoded_string = url_encode(decoded_string)
        template = template.sub(match[0], encoded_string)
      else
        template = template.sub(match[0], match[1])
      end
    end

    template.scan(/(\[([^\[]*?),\s?url_safe\s?([^\}]*?)\])/i,) do |match|
      if !match[1].blank?
        decoded_string = URI.decode(match[1])
        url_safe_string = decoded_string.gsub(/[^a-zA-Z0-9.@\s]/, "")
        template = template.sub(match[0], url_encode(url_safe_string))
      else
        template = template.sub(match[0], match[1])
      end
    end

    template.scan(/(\[(.*?),\s?trim\s?\])/i,) do |match|
      if !match[1].blank?
        template = template.sub(match[0], match[1].strip)
      else
        template = template.sub(match[0], match[1])
      end
    end

    template
  end

  def float?(value)
    return false if value.blank?

    begin
      Float(value) != nil
    rescue StandardError
      false
    end
  end

  def get_object(name)
    result = nil
    @objects.each do |object|
      object_name = "#{object.try(:class).try(:name)}".downcase
      result = object if object_name == name.to_s
    end
    result
  end

  def generic_translations
    hash = Hash.new

    if @tracker.nil?
      uuid = "invalid"
    else
      uuid = @tracker.uuid
    end

    hash =
    {
        # 'view_online' => %Q{<a href="#{view_online_url}">View Online</a>}.html_safe,
        "view_online" => Tracker.view_email_url(uuid),
        "attachments" => %Q{<!-- ATTACHMENTS -->} # If you change this value make sure to update the attchment hint_text in email.rb#send_email
    }

    hash.merge!(generic_button_translations)
    hash
  end

  def generic_button_translations
    user = get_object(:user)
    hash = Hash.new

    identity = get_object(:identity)
    generic_email = user.email unless user.nil?
    generic_email = identity.email_marketing unless identity.nil?

    if !generic_email.blank?
      generic_buttons =
      {
          "button_estimate" => button_wrapper("Estimate", "#234588", "mailto:#{generic_email}?subject=#{url_encode(%Q{Please provide me with a new estimate})}"),
          "button_meeting" => button_wrapper("Meeting", "#79c251", "mailto:#{generic_email}?subject=#{url_encode(%Q{Please can we meet to discuss a new project})}"),
          "button_order" => button_wrapper("Order", "#79c251", "mailto:#{generic_email}?subject=#{url_encode(%Q{Please can I place a new order with you})}"),
      }
      hash.merge!(generic_buttons) if !@draft
    end
    hash
  end

  def portalcomment_translations(comment)
    {
      "comment_body" => comment.body,
      "comment_name" => comment.commenter_name
    }
  end

  def tenant_translations(tenant)
    identity = get_object(:identity)
    identity = tenant if identity.nil?
    hash = {
      "centre_name" => identity.name,
      "centre_contact" => identity.contact_name,
      "centre_number" => identity.number,
      "phone" => identity.phone,
      "address_1" => identity.address_1,
      "address_2" => identity.address_2,
      "address_single_line" => lambda { ApplicationController.helpers.combined_address(identity.address_1, identity.address_2) },
      "address_multi_line" => lambda { ApplicationController.helpers.combined_address(identity.address_1, identity.address_2, "<br>") },
      "suburb" => identity.suburb,
      "state" => identity.state,
      "postcode" => identity.postcode,
      "email_marketing" => identity.email_marketing,
      "business_hours" => identity.business_hours,
      "holiday_last_day" => identity.holiday_last_day,
      "holiday_returning" => identity.holiday_returning,
      "website_url" => identity.website_url,
      "blog" => identity.blog,
      "request_a_quote" => "#{identity.request_quote_url}?rnd=#{Random.rand}",
      "request_quote_url" => "#{identity.request_quote_url}?rnd=#{Random.rand}",
      "facebook" => identity.facebook,
      "twitter" => identity.twitter,
      "instagram" => identity.instagram,
      "pinterest" => identity.pinterest,
      "youtube" => identity.youtube,
      "review_url" => identity.review_url,
      "linked_in" => identity.linked_in
    }

    (0..30).each do |i|
      if i == 0
        hash["date_today"] = lambda { tenant.try(:local_strftime, Date.today, "%%DM-%%DM-%Y", "") }
      else
        hash["date_plus_#{i}"] = lambda { tenant.try(:local_strftime, Date.today + i.days, "%%DM-%%DM-%Y", "") }
      end
    end

    hash
  end

  def user_translations(user)
    tenant = get_object(:tenant)
    hash = {
      "email_address" => user.email,
      "centre_contact" => "#{user.first_name} #{user.last_name}",
      "user_first_name" => user.first_name,
      "user_last_name" => user.last_name,
      "email_signature" => user.email_signature_merged(tenant),
    }
    hash
  end

  def contact_translations(contact)
    tenant = get_object(:tenant)
    hash = {
      "first_name" => contact.try(:first_name),
      "last_name" => contact.try(:last_name),
      "contact_first_name" => contact.try(:first_name),
      "contact_last_name" => contact.try(:last_name),
      "contact_phone" => contact.try(:phone),
      "contact_email" => contact.try(:email),
      "contact_address_name" => lambda { contact.try(:lookup_address).try(:name) },
      "contact_address_1" => lambda { contact.try(:lookup_address).try(:street1) },
      "contact_address_2" => lambda { contact.try(:lookup_address).try(:street2) },
      "contact_address_single_line" => lambda { ApplicationController.helpers.combined_address(contact.try(:lookup_address).try(:street1), contact.try(:lookup_address).try(:street2)) },
      "contact_address_multi_line" => lambda { ApplicationController.helpers.combined_address(contact.try(:lookup_address).try(:street1), contact.try(:lookup_address).try(:street2), "<br>") },
      "contact_suburb" => lambda { contact.try(:lookup_address).try(:city) },
      "contact_state" => lambda { contact.try(:lookup_address).try(:state) },
      "contact_postcode" => lambda { contact.try(:lookup_address).try(:zip) },
      "contact_sales_rep" => lambda { (contact.try(:sales_rep_user) || contact.try(:company).try(:sales_rep_user)).try(:full_name) },
      "contact_sales_rep_email" => lambda { (contact.try(:sales_rep_user) || contact.try(:company).try(:sales_rep_user)).try(:tenant_email, tenant) },
      "contact_sales_rep_first_name" => lambda { (contact.try(:sales_rep_user) || contact.try(:company).try(:sales_rep_user)).try(:first_name) },
      "contact_sales_rep_last_name" => lambda { (contact.try(:sales_rep_user) || contact.try(:company).try(:sales_rep_user)).try(:last_name) },
      "contact_location" => lambda { (contact.try(:location) || contact.try(:company).try(:location)).try(:name) },
      "contact_sales_rep_or_location" => lambda { contact.try(:tenant).try(:sales_rep_for_locations) ? (contact.try(:location) || contact.try(:company).try(:location)).try(:name) : (contact.try(:sales_rep_user) || contact.try(:company).try(:sales_rep_user)).try(:full_name) },
      "contact_company_name" => lambda { contact.try(:company).try(:name) },
      "contact_first_sale_date" => lambda {
                                                    first_sale = contact.sales.minimum(:pickup_date)
                                                    first_sale.blank? ? "Never" : contact.tenant.try(:local_strftime, first_sale, "%%DM-%%DM-%Y", "")
                                                  },
    }
    hash.merge!(contact_button_translations(contact, get_object(:user)))
    hash
  end

  def contact_button_translations(contact, user)
    phone_number = contact.phone
    phone_number = contact.mobile if phone_number.blank?
    phone_number = " at #{phone_number}" unless phone_number.blank?
    hash = Hash.new

    identity = get_object(:identity)
    generic_email = user.email unless user.nil?
    generic_email = identity.email_marketing unless identity.nil?

    if !generic_email.blank?
      contact_buttons =
      {
        "button_call_contact" => button_wrapper("Call", "#79c251", "mailto:#{generic_email}?subject=#{url_encode(%Q{Please call me#{phone_number} as soon as possible, I have an inquiry I would like to discuss with you})}")
      }
      hash.merge!(contact_buttons) if !@draft
    end
    hash
  end

  def contextual_button_translations(object, user)
    # name = object.name.try { truncate(40) }
    name = object.name
    number = object.invoice_number
    hash = Hash.new

    if user
      # view_pdf_url = Rails.application.routes.url_helpers.view_pdf_url(key: object.key || 'invalid', platform_id: object.platform_id || 'invalid')
      # download_pdf_url = Rails.application.routes.url_helpers.download_pdf_url(key: object.key || 'invalid', platform_id: object.platform_id || 'invalid')
      view_pdf_url = Pdf.presigned_pdf(object, inline: true, expires_in: 604800)
      download_pdf_url = Pdf.presigned_pdf(object, inline: false, expires_in: 604800)
      estimate_view_url = ""
      estimate_view_url = object.portal_url if object.class == Estimate
      proof_view_url = object.portal_url if [Order, Sale, Invoice].include?(object.class)

      object_buttons =
      {
        "button_approve" => button_wrapper("Approve", "#19ac47", "mailto:#{user.email}?subject=#{url_encode(%Q{APPROVED - Estimate:##{number}})}&body=#{url_encode(%Q{Please go ahead with estimate ##{number} for #{name} and contact me to let me know when it will be ready.})}"),
        "button_add" => button_wrapper("Add", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{Please can I add to ##{number} #{name}})}"),
        "button_call" => button_wrapper("Call", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{Please call me to discuss estimate ##{number} #{name}})}"),
        "button_concerned" => button_wrapper("Concerned", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{We had some concerns regarding ##{number} #{name}})}"),
        "button_delighted" => button_wrapper("Delighted", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{Some positive feedback re: ##{number} #{name}})}"),
        # 'button_improve'         => button_wrapper("Improve", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{Help us improve estimate ##{number} #{name}})}"),
        "button_remind" => button_wrapper("Remind", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{Please remind me to re-order  ##{number} #{name}})}"),
        # 'button_resend'          => button_wrapper("Resend", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{Please send me a copy of estimate ##{number} #{name}})}"),
        # 'button_save'            => button_wrapper("Save", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{Please save ##{number} #{name} for future reference})}"),
        # 'button_sooner'          => button_wrapper("Sooner", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{If possible I need ##{number} #{name} sooner})}"),
        # 'button_voucher'         => button_wrapper("Voucher", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{Please send me my 10% voucher for ##{number} #{name}})}"),
        "button_re-order" => button_wrapper("Re-Order", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{Please re-order ##{number} #{name}})}"),
        "button_view_estimate" => button_wrapper("View Estimate", "#234588", estimate_view_url),
        "button_view_estimate_accept" => button_wrapper("View Estimate", "#234588", estimate_view_url),
        "button_view_invoice" => button_wrapper(I18n.t("view_invoice"), "#234588", view_pdf_url),
        "button_download_estimate" => button_wrapper("Download Estimate", "#234588", download_pdf_url),
        "button_download_invoice" => button_wrapper(I18n.t("download_invoice"), "#234588", download_pdf_url),
        "button_proof_approval" => button_wrapper("Approve", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{Approval for ##{number} for #{name}})}&body=#{url_encode(%Q{Please proceed with the production ##{number} for #{name}. I have examined the proof carefully and am happy that it is correct. I understand that if, following this approval, an error is subsequently discovered that I may be liable for the cost of a reprint.})}"),
        "button_changes_needed" => button_wrapper("Changes Needed", "#79c251", "mailto:#{user.email}?subject=#{url_encode(%Q{Proof changes for ##{number} for #{name}})}&body=#{url_encode(%Q{Please make the following changes to the submitted proof and send a new proof for order ##{number} for #{name}.})}"),
        "button_view_proof" => button_wrapper("View Proof", "#234588", proof_view_url),
        ####################
        # AGI GREY BUTTONS #
        ####################
        "button_approve_grey" => button_wrapper("Approve", "#76787b", "mailto:#{user.email}?subject=#{url_encode(%Q{APPROVED - Estimate:##{number}})}&body=#{url_encode(%Q{Please go ahead with estimate ##{number} for #{name} and contact me to let me know when it will be ready.})}"),
        "button_add_grey" => button_wrapper("Add", "#76787b", "mailto:#{user.email}?subject=#{url_encode(%Q{Please can I add to ##{number} #{name}})}"),
        "button_call_grey" => button_wrapper("Call", "#76787b", "mailto:#{user.email}?subject=#{url_encode(%Q{Please call me to discuss estimate ##{number} #{name}})}"),
        "button_concerned_grey" => button_wrapper("Concerned", "#76787b", "mailto:#{user.email}?subject=#{url_encode(%Q{We had some concerns regarding ##{number} #{name}})}"),
        "button_delighted_grey" => button_wrapper("Delighted", "#76787b", "mailto:#{user.email}?subject=#{url_encode(%Q{Some positive feedback re: ##{number} #{name}})}"),
        "button_remind_grey" => button_wrapper("Remind", "#76787b", "mailto:#{user.email}?subject=#{url_encode(%Q{Please remind me to re-order  ##{number} #{name}})}"),
        "button_re-order_grey" => button_wrapper("Re-Order", "#76787b", "mailto:#{user.email}?subject=#{url_encode(%Q{Please re-order ##{number} #{name}})}"),
        "button_view_estimate_grey" => button_wrapper("View Estimate", "#76787b", estimate_view_url),
        "button_view_estimate_accept_grey" => button_wrapper("View Estimate", "#76787b", estimate_view_url),
        "button_view_invoice_grey" => button_wrapper(I18n.t("view_invoice"), "#76787b", view_pdf_url),
        "button_download_estimate_grey" => button_wrapper("Download Estimate", "#76787b", download_pdf_url),
        "button_download_invoice_grey" => button_wrapper(I18n.t("download_invoice"), "#76787b", download_pdf_url),
        "button_proof_approval_grey" => button_wrapper("Approve", "#76787b", "mailto:#{user.email}?subject=#{url_encode(%Q{Approval for ##{number} for #{name}})}&body=#{url_encode(%Q{Please proceed with the production ##{number} for #{name}. I have examined the proof carefully and am happy that it is correct. I understand that if, following this approval, an error is subsequently discovered that I may be liable for the cost of a reprint.})}"),
        "button_changes_needed_grey" => button_wrapper("Changes Needed", "#76787b", "mailto:#{user.email}?subject=#{url_encode(%Q{Proof changes for ##{number} for #{name}})}&body=#{url_encode(%Q{Please make the following changes to the submitted proof and send a new proof for order ##{number} for #{name}.})}"),
        "button_view_proof_grey" => button_wrapper("View Proof", "#76787b", proof_view_url)
      }

      object_links =
      {
        "link_view_estimate" => estimate_view_url,
        "link_view_invoice" => view_pdf_url,
        "link_download_invoice" => download_pdf_url,
        "link_view_proof" => proof_view_url
      }


      hash.merge!(object_buttons) if !@draft
      hash.merge!(object_links) if !@draft
    end

    hash
  end

  def invoice_translations(invoice)
    # name = invoice.name.try { truncate(40) }
    tenant = get_object(:tenant)
    name = invoice.name
    number = invoice.invoice_number
    amount_due = invoice.try(:amount_due) || 0
    amount = invoice.try(:grand_total) || 0
    hash =
    {
      "invoice_number" => number,
      "invoice_description" => name,
      "invoice_date" => invoice.try(:tenant).try(:local_strftime, invoice.created_at, "%%DM-%%DM-%Y", ""),
      "proof_by" => invoice.try(:tenant).try(:local_strftime, invoice.proof_by, "%%DM-%%DM-%Y", ""),
      "po_number" => invoice.try(:customer_po),
      "invoice_amount" => "#{"%.02f" % amount}",
      "invoice_amount_due" => "#{"%.02f" % amount_due}",
      "90_percent_of_invoice_amount_due" => "#{"%.02f" % (amount_due * 0.9)}",
      "80_percent_of_invoice_amount_due" => "#{"%.02f" % (amount_due * 0.8)}",
      "70_percent_of_invoice_amount_due" => "#{"%.02f" % (amount_due * 0.7)}",
      "60_percent_of_invoice_amount_due" => "#{"%.02f" % (amount_due * 0.6)}",
      "50_percent_of_invoice_amount_due" => "#{"%.02f" % (amount_due * 0.5)}",
      "40_percent_of_invoice_amount_due" => "#{"%.02f" % (amount_due * 0.4)}",
      "30_percent_of_invoice_amount_due" => "#{"%.02f" % (amount_due * 0.3)}",
      "20_percent_of_invoice_amount_due" => "#{"%.02f" % (amount_due * 0.2)}",
      "10_percent_of_invoice_amount_due" => "#{"%.02f" % (amount_due * 0.1)}",
      "estimate_number" => number,
      "estimate_description" => name,
      "taken_by" => invoice.try(:taken_by_user).try(:full_name),
      "taken_by_first_name" => invoice.try(:taken_by_user).try(:first_name),
      "taken_by_last_name" => invoice.try(:taken_by_user).try(:last_name)
    }

    if !@draft
      hash.merge!({
        "invoice_pay_url_amount" => "#{'%.02f' % amount_due}",
        "invoice_pay_url_number" => invoice.try(:invoice_number).try(:to_s) || "",
        "invoice_pay_url_name" => invoice.try(:company).try(:name) || invoice.try(:contact).try(:full_name) || "",
        "invoice_pay_url_email" => @custom[:email_address] || invoice.try(:contact).try(:email) || "",
        "pay_url" => invoice.try(:pay_url, target_tenant: invoice.try(:tenant) || tenant, email: @custom[:email_address]),
        "wanted_by" => invoice.try(:tenant).try(:local_strftime, invoice.wanted_by, "%%DM-%%DM-%Y", "")
      })
    end

    hash.merge!(contextual_button_translations(invoice, get_object(:user)))
    hash.merge!(sales_rep_translations(invoice))
  end

  def sales_rep_translations(context)
    hash = {
      "location" => context.try(:location).try(:name),
      "sales_rep" => context.try(:sales_rep_user).try(:full_name),
      "sales_rep_first_name" => context.try(:sales_rep_user).try(:first_name),
      "sales_rep_last_name" => context.try(:sales_rep_user).try(:last_name),
      "sales_rp_or_location" => context.try(:tenant).try(:sales_rep_for_locations) ? context.try(:location).try(:name) : context.try(:sales_rep_user).try(:full_name)
    }
  end

  def estimate_translations(estimate)
    invoice_translations(estimate)
  end

  def order_translations(order)
    invoice_translations(order)
  end

  def sale_translations(sale)
    invoice_translations(sale)
  end

  def shipment_translations(shipment)
    hash =
    {
      "tracking_number" => shipment.courier_tracking,
      "mbe_tracking_number" => shipment.mbe_tracking,
      "shipment_date" => shipment.tenant.try(:local_strftime, shipment.shipment_date, "%%DM-%%DM-%y"),
      "delivery_date" => shipment.tenant.try(:local_strftime, shipment.delivered_date, "%%DM-%%DM-%y"),
      "courier" => shipment.courier_name,
      "service_type" => shipment.courier_service,
      "sender" => shipment.platform_data.try(:[], "addressFrom").try(:[], "companyName"),
      "reciever" => shipment.platform_data.try(:[], "addressTo").try(:[], "companyName"),
      "shipping_value" => shipment.grand_total,
    }
    hash.merge!(sales_rep_translations(shipment))
  end

  def campaign_translations(campaign)
    tenant = get_object(:tenant)
    if @tracker.nil?
      uuid = "invalid"
    else
      uuid = @tracker.uuid
    end

    unsubscribe_url = Tracker.unsubscribe_url(uuid)

    hash = {
        # 'campaign_name'            => campaign.name,
        # 'campaign_description'     => campaign.description,
        # 'unsubscribe' => %Q{<a href="#{unsubscribe_url}">Unsubscribe</a>}.html_safe,
        "unsubscribe" => unsubscribe_url,
        "unsubscribe_template" => lambda {
                                           unsubscribe_template = tenant.try(:enterprise).try(:unsubscribe_template)
                                           unsubscribe_template = %Q{<a href="{{unsubscribe}}">Unsubscribe</a>} if unsubscribe_template.blank? || !unsubscribe_template.include?("{{unsubscribe}}")
                                           unsubscribe_template.try(:gsub, "{{unsubscribe}}", escape_content(unsubscribe_url)).try(:html_safe)
                                         }
    }
    hash
  end

  def escape_content(content)
    content = content || ""
    content = content.to_s
    content = content.gsub(/'/, "\'").gsub(/’/, "\’").gsub(/\r/, " ").gsub(/\n/, " ").gsub(/\s+/, " ").gsub(/’/, "\’").strip
    content
  end

  def button_wrapper(text, color, href)
    tenant = get_object(:tenant)
    if tenant.enterprise.agi_brand
      agi_color = (color == "#76787b") ? "#76787b" : "#DA291C"

      %Q{
          <!-- BUTTON -->
          <table style="width:100%;">
            <tr>
            <td align="center" style=" padding:10px 40px 10px 40px;">
              <table style="display: inline-block" cellspacing="0" cellpadding="0" border="0">
                <tbody>
                  <tr>
                    <td style="padding: 6px 24px; -webkit-border-radius:3px; border-radius:5px" bgcolor="#{agi_color}" align="center">
                      <b><a href="#{href}" target="_blank" style="font-size :16px; font-family: 'Roboto Slab', Arial, sans-serif; color: rgb(255, 255, 255); text-decoration: none; display: inline-block; vertical-align: middle;  text-transform: uppercase;">
                      <font face="'Roboto Slab', Arial, sans-serif;">
                        #{text}
                      </font>
                      </a>
                    </b></td>
                  </tr>
                </tbody>
              </table>
            </td>
            </tr>
          </table>
          <!-- // END BUTTON -->

      }.html_safe
    else
      %Q{
        <table border="0" cellspacing="0" cellpadding="0">
          <tr>
            <td bgcolor="#{color}" style="padding: 8px 24px 8px 24px; -webkit-border-radius:3px; border-radius:3px" align="center">
              <a href="#{href}" target="_blank" style="font-size: 14px; font-family: Helvetica, Arial, sans-serif; font-weight: normal; color: #ffffff; text-decoration: none; display: inline-block;">
                #{text}
              </a>
            </td>
          </tr>
        </table>
    }.html_safe
    end
  end

  def include_roboto_font
    %Q{
      <style type="text/css">

      /* cyrillic-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto Italic'), local('Roboto-Italic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOkCnqEu92Fr1Mu51xFIzIXKMnyrYk.woff2) format('woff2');
        unicode-range: U+0460-052F, U+1C80-1C88, U+20B4, U+2DE0-2DFF, U+A640-A69F, U+FE2E-FE2F;
      }
      /* cyrillic */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto Italic'), local('Roboto-Italic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOkCnqEu92Fr1Mu51xMIzIXKMnyrYk.woff2) format('woff2');
        unicode-range: U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116;
      }
      /* greek-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto Italic'), local('Roboto-Italic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOkCnqEu92Fr1Mu51xEIzIXKMnyrYk.woff2) format('woff2');
        unicode-range: U+1F00-1FFF;
      }
      /* greek */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto Italic'), local('Roboto-Italic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOkCnqEu92Fr1Mu51xLIzIXKMnyrYk.woff2) format('woff2');
        unicode-range: U+0370-03FF;
      }
      /* vietnamese */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto Italic'), local('Roboto-Italic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOkCnqEu92Fr1Mu51xHIzIXKMnyrYk.woff2) format('woff2');
        unicode-range: U+0102-0103, U+0110-0111, U+0128-0129, U+0168-0169, U+01A0-01A1, U+01AF-01B0, U+1EA0-1EF9, U+20AB;
      }
      /* latin-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto Italic'), local('Roboto-Italic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOkCnqEu92Fr1Mu51xGIzIXKMnyrYk.woff2) format('woff2');
        unicode-range: U+0100-024F, U+0259, U+1E00-1EFF, U+2020, U+20A0-20AB, U+20AD-20CF, U+2113, U+2C60-2C7F, U+A720-A7FF;
      }
      /* latin */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto Italic'), local('Roboto-Italic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOkCnqEu92Fr1Mu51xIIzIXKMny.woff2) format('woff2');
        unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+2000-206F, U+2074, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
      }
      /* cyrillic-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold Italic'), local('Roboto-BoldItalic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOjCnqEu92Fr1Mu51TzBic3CsTYl4BOQ3o.woff2) format('woff2');
        unicode-range: U+0460-052F, U+1C80-1C88, U+20B4, U+2DE0-2DFF, U+A640-A69F, U+FE2E-FE2F;
      }
      /* cyrillic */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold Italic'), local('Roboto-BoldItalic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOjCnqEu92Fr1Mu51TzBic-CsTYl4BOQ3o.woff2) format('woff2');
        unicode-range: U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116;
      }
      /* greek-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold Italic'), local('Roboto-BoldItalic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOjCnqEu92Fr1Mu51TzBic2CsTYl4BOQ3o.woff2) format('woff2');
        unicode-range: U+1F00-1FFF;
      }
      /* greek */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold Italic'), local('Roboto-BoldItalic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOjCnqEu92Fr1Mu51TzBic5CsTYl4BOQ3o.woff2) format('woff2');
        unicode-range: U+0370-03FF;
      }
      /* vietnamese */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold Italic'), local('Roboto-BoldItalic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOjCnqEu92Fr1Mu51TzBic1CsTYl4BOQ3o.woff2) format('woff2');
        unicode-range: U+0102-0103, U+0110-0111, U+0128-0129, U+0168-0169, U+01A0-01A1, U+01AF-01B0, U+1EA0-1EF9, U+20AB;
      }
      /* latin-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold Italic'), local('Roboto-BoldItalic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOjCnqEu92Fr1Mu51TzBic0CsTYl4BOQ3o.woff2) format('woff2');
        unicode-range: U+0100-024F, U+0259, U+1E00-1EFF, U+2020, U+20A0-20AB, U+20AD-20CF, U+2113, U+2C60-2C7F, U+A720-A7FF;
      }
      /* latin */
      @font-face {
        font-family: 'Roboto';
        font-style: italic;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold Italic'), local('Roboto-BoldItalic'), url(https://fonts.gstatic.com/s/roboto/v20/KFOjCnqEu92Fr1Mu51TzBic6CsTYl4BO.woff2) format('woff2');
        unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+2000-206F, U+2074, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
      }
      /* cyrillic-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto'), local('Roboto-Regular'), url(https://fonts.gstatic.com/s/roboto/v20/KFOmCnqEu92Fr1Mu72xKKTU1Kvnz.woff2) format('woff2');
        unicode-range: U+0460-052F, U+1C80-1C88, U+20B4, U+2DE0-2DFF, U+A640-A69F, U+FE2E-FE2F;
      }
      /* cyrillic */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto'), local('Roboto-Regular'), url(https://fonts.gstatic.com/s/roboto/v20/KFOmCnqEu92Fr1Mu5mxKKTU1Kvnz.woff2) format('woff2');
        unicode-range: U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116;
      }
      /* greek-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto'), local('Roboto-Regular'), url(https://fonts.gstatic.com/s/roboto/v20/KFOmCnqEu92Fr1Mu7mxKKTU1Kvnz.woff2) format('woff2');
        unicode-range: U+1F00-1FFF;
      }
      /* greek */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto'), local('Roboto-Regular'), url(https://fonts.gstatic.com/s/roboto/v20/KFOmCnqEu92Fr1Mu4WxKKTU1Kvnz.woff2) format('woff2');
        unicode-range: U+0370-03FF;
      }
      /* vietnamese */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto'), local('Roboto-Regular'), url(https://fonts.gstatic.com/s/roboto/v20/KFOmCnqEu92Fr1Mu7WxKKTU1Kvnz.woff2) format('woff2');
        unicode-range: U+0102-0103, U+0110-0111, U+0128-0129, U+0168-0169, U+01A0-01A1, U+01AF-01B0, U+1EA0-1EF9, U+20AB;
      }
      /* latin-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto'), local('Roboto-Regular'), url(https://fonts.gstatic.com/s/roboto/v20/KFOmCnqEu92Fr1Mu7GxKKTU1Kvnz.woff2) format('woff2');
        unicode-range: U+0100-024F, U+0259, U+1E00-1EFF, U+2020, U+20A0-20AB, U+20AD-20CF, U+2113, U+2C60-2C7F, U+A720-A7FF;
      }
      /* latin */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: local('Roboto'), local('Roboto-Regular'), url(https://fonts.gstatic.com/s/roboto/v20/KFOmCnqEu92Fr1Mu4mxKKTU1Kg.woff2) format('woff2');
        unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+2000-206F, U+2074, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
      }
      /* cyrillic-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold'), local('Roboto-Bold'), url(https://fonts.gstatic.com/s/roboto/v20/KFOlCnqEu92Fr1MmWUlfCRc4AMP6lbBP.woff2) format('woff2');
        unicode-range: U+0460-052F, U+1C80-1C88, U+20B4, U+2DE0-2DFF, U+A640-A69F, U+FE2E-FE2F;
      }
      /* cyrillic */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold'), local('Roboto-Bold'), url(https://fonts.gstatic.com/s/roboto/v20/KFOlCnqEu92Fr1MmWUlfABc4AMP6lbBP.woff2) format('woff2');
        unicode-range: U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116;
      }
      /* greek-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold'), local('Roboto-Bold'), url(https://fonts.gstatic.com/s/roboto/v20/KFOlCnqEu92Fr1MmWUlfCBc4AMP6lbBP.woff2) format('woff2');
        unicode-range: U+1F00-1FFF;
      }
      /* greek */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold'), local('Roboto-Bold'), url(https://fonts.gstatic.com/s/roboto/v20/KFOlCnqEu92Fr1MmWUlfBxc4AMP6lbBP.woff2) format('woff2');
        unicode-range: U+0370-03FF;
      }
      /* vietnamese */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold'), local('Roboto-Bold'), url(https://fonts.gstatic.com/s/roboto/v20/KFOlCnqEu92Fr1MmWUlfCxc4AMP6lbBP.woff2) format('woff2');
        unicode-range: U+0102-0103, U+0110-0111, U+0128-0129, U+0168-0169, U+01A0-01A1, U+01AF-01B0, U+1EA0-1EF9, U+20AB;
      }
      /* latin-ext */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold'), local('Roboto-Bold'), url(https://fonts.gstatic.com/s/roboto/v20/KFOlCnqEu92Fr1MmWUlfChc4AMP6lbBP.woff2) format('woff2');
        unicode-range: U+0100-024F, U+0259, U+1E00-1EFF, U+2020, U+20A0-20AB, U+20AD-20CF, U+2113, U+2C60-2C7F, U+A720-A7FF;
      }
      /* latin */
      @font-face {
        font-family: 'Roboto';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: local('Roboto Bold'), local('Roboto-Bold'), url(https://fonts.gstatic.com/s/roboto/v20/KFOlCnqEu92Fr1MmWUlfBBc4AMP6lQ.woff2) format('woff2');
        unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+2000-206F, U+2074, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
      }


      /* cyrillic-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufA5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0460-052F, U+1C80-1C88, U+20B4, U+2DE0-2DFF, U+A640-A69F, U+FE2E-FE2F;
      }
      /* cyrillic */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufJ5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116;
      }
      /* greek-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufB5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+1F00-1FFF;
      }
      /* greek */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufO5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0370-03FF;
      }
      /* vietnamese */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufC5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0102-0103, U+0110-0111, U+0128-0129, U+0168-0169, U+01A0-01A1, U+01AF-01B0, U+1EA0-1EF9, U+20AB;
      }
      /* latin-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufD5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0100-024F, U+0259, U+1E00-1EFF, U+2020, U+20A0-20AB, U+20AD-20CF, U+2113, U+2C60-2C7F, U+A720-A7FF;
      }
      /* latin */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 400;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufN5qWr4xCC.woff2) format('woff2');
        unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+2000-206F, U+2074, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
      }
      /* cyrillic-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 500;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufA5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0460-052F, U+1C80-1C88, U+20B4, U+2DE0-2DFF, U+A640-A69F, U+FE2E-FE2F;
      }
      /* cyrillic */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 500;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufJ5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116;
      }
      /* greek-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 500;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufB5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+1F00-1FFF;
      }
      /* greek */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 500;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufO5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0370-03FF;
      }
      /* vietnamese */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 500;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufC5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0102-0103, U+0110-0111, U+0128-0129, U+0168-0169, U+01A0-01A1, U+01AF-01B0, U+1EA0-1EF9, U+20AB;
      }
      /* latin-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 500;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufD5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0100-024F, U+0259, U+1E00-1EFF, U+2020, U+20A0-20AB, U+20AD-20CF, U+2113, U+2C60-2C7F, U+A720-A7FF;
      }
      /* latin */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 500;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufN5qWr4xCC.woff2) format('woff2');
        unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+2000-206F, U+2074, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
      }
      /* cyrillic-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 600;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufA5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0460-052F, U+1C80-1C88, U+20B4, U+2DE0-2DFF, U+A640-A69F, U+FE2E-FE2F;
      }
      /* cyrillic */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 600;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufJ5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116;
      }
      /* greek-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 600;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufB5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+1F00-1FFF;
      }
      /* greek */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 600;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufO5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0370-03FF;
      }
      /* vietnamese */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 600;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufC5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0102-0103, U+0110-0111, U+0128-0129, U+0168-0169, U+01A0-01A1, U+01AF-01B0, U+1EA0-1EF9, U+20AB;
      }
      /* latin-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 600;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufD5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0100-024F, U+0259, U+1E00-1EFF, U+2020, U+20A0-20AB, U+20AD-20CF, U+2113, U+2C60-2C7F, U+A720-A7FF;
      }
      /* latin */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 600;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufN5qWr4xCC.woff2) format('woff2');
        unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+2000-206F, U+2074, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
      }
      /* cyrillic-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufA5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0460-052F, U+1C80-1C88, U+20B4, U+2DE0-2DFF, U+A640-A69F, U+FE2E-FE2F;
      }
      /* cyrillic */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufJ5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116;
      }
      /* greek-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufB5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+1F00-1FFF;
      }
      /* greek */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufO5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0370-03FF;
      }
      /* vietnamese */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufC5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0102-0103, U+0110-0111, U+0128-0129, U+0168-0169, U+01A0-01A1, U+01AF-01B0, U+1EA0-1EF9, U+20AB;
      }
      /* latin-ext */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufD5qWr4xCCQ_k.woff2) format('woff2');
        unicode-range: U+0100-024F, U+0259, U+1E00-1EFF, U+2020, U+20A0-20AB, U+20AD-20CF, U+2113, U+2C60-2C7F, U+A720-A7FF;
      }
      /* latin */
      @font-face {
        font-family: 'Roboto Slab';
        font-style: normal;
        font-weight: 700;
        font-display: swap;
        src: url(https://fonts.gstatic.com/s/robotoslab/v12/BngMUXZYTXPIvIBgJJSb6ufN5qWr4xCC.woff2) format('woff2');
        unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+2000-206F, U+2074, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
      }

      </style>

    }.html_safe
  end
end
