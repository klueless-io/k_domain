class Inquiry < ActiveRecord::Base
  include Categorizable

  has_many :inquiry_attachments

  enum inquiry_type: { Website: 1, Email: 2 }

  enum inquiry_status: {
    "Unread": 0,
    "Read": 7,
    "Awaiting Details": 1,
    "In progress": 2,
    "Replied": 3,
    "Won": 4,
    "Lost": 5,
    "Archived": 6
  }

  enum inquiry_lost_reason: {
    "Do not offer products/services requested": 1,
    "Test inquiry": 2,
    "Insufficient information to quote": 3,
    "Unable to reach contact": 4,
    "Responded too late": 5,
    "Estimate lost": 6,
    "SPAM": 7
  }

  enum inquiry_identifier: {
    "Quote Request": 1,
    "Send a file": 2,
    "Contact us": 3,
    "Shipment Request": 4,
    "General": 5,
    "Logistica": 6,
    "e-link": 7,
    "Web Services": 8,
    "Touch": 9,
    "Address": 10,
    "Spedizioni-imballaggio": 11,
    "Printing-Marketing": 12,
    "E-commerce": 13,
    "SafeValue": 14,
    "1M Project": 15
  }

  belongs_to :tenant
  belongs_to :user
  belongs_to :contact
  belongs_to :company
  has_many :activities

  has_many :phone_calls, as: :phoneable
  has_many :tasks, as: :taskable
  has_many :notes, as: :context
  has_many :meetings, as: :context
  # has_many :emails, as: :context

  def sales_rep
    SalesRep.where("platform_id = ? AND tenant_id = ?", sales_rep_platform_id, tenant_id).where(deleted: false).first
  end

  def name
    if contact_id
      tenant.contacts.where(id: contact_id).first.try(:full_name)
    else
      first_name.to_s + " " + last_name.to_s
    end
  end

  def send_new_email(host, changing_user = nil)
    return unless inquiry_send_email_allowed?("send_new_email")

    to_addrs = get_email_addresses(changing_user)
    email_body = Emails::Inquiry.new.new_inquiry(self, host)
    send_mail(to_addrs, "Print Speak: New Inquiry created", email_body) if to_addrs.present?
  end

  def send_new_api_email
    return unless inquiry_send_email_allowed?("send_new_api_email")
    return unless user

    dest_address = test_mode_if_required(user.tenant_email(tenant))
    message = "A new Inquiry has been created:"

    if !try(:contact)
      inquiry_name = try(:first_name).to_s + " " + try(:last_name).to_s if try(:first_name) || try(:last_name)
      inquiry_email = try(:from_email)
    else
      inquiry_name = contact.full_name
      inquiry_email = contact.email
    end

    body = <<-EOF
      <p>
        Hi #{try(:user).try(:full_name)},
      </p>

      <p>
        #{message}
      </p>

      <table>
      <tr>
        <td width="150"  style="padding:8px;">Name: </td>
        <td  style="padding:8px;">#{inquiry_name }</td>
      </tr>
      <tr>
        <td width="150"  style="padding:8px;">Email: </td>
        <td  style="padding:8px;">#{ inquiry_email }</td>
      </tr>
      <tr>
        <td width="150" style="padding:8px;">Inquiry Company: </td>
        <td  style="padding:8px;">#{ try(:company) ? company.try(:name) : company_name }</td>
      </tr>
      <tr>
        <td width="150" style="padding:8px;">Assigned User:</td>
        <td style="padding:8px;"><strong>#{ try(:user).try(:full_name) }<strong></td>
      </tr>
      <tr>
        <td width="150"  style="padding:8px;">Status: </td>
        <td  style="padding:8px;">#{ try(:inquiry_status) }</td>
      </tr>
      <tr>
          <td  style="padding:8px;">Link: </td>
          <td  style="padding:8px;"><a href="#{Rails.application.routes.url_helpers.url_for(controller: :inquiries, action: :edit, id: id)}">View in Print Speak</a></td>
        </tr>
      </table>
  EOF

    Email.ses_send([dest_address], "Print Speak: New Inquiry created", Email.printspeak_template(body)) if dest_address.present?
  end

  def send_assigned_user_change_email(host, changing_user = nil)
    return unless inquiry_send_email_allowed?("send_assigned_user_change_email")
    to_addrs = get_email_addresses(changing_user)
    email_body = Emails::Inquiry.new.assigned_user_update(self, host)
    send_mail(to_addrs, "Print Speak: Inquiry assigned user changed to: #{user.full_name}", email_body) if to_addrs.present?
  end

  def send_contact_change_email(host, changing_user = nil)
    return unless inquiry_send_email_allowed?("send_contact_change_email")
    to_addrs = get_email_addresses(changing_user)
    message = contact.present? ? "contact assigned" : "contact cleared"
    email_body = Emails::Inquiry.new.contact_update(self, host)
    send_mail(to_addrs, "Print Speak: Inquiry #{message}", email_body) if to_addrs.present?
  end

  def send_company_change_email(host, changing_user = nil)
    return unless inquiry_send_email_allowed?("send_company_change_email")
    to_addrs = get_email_addresses(changing_user)
    message = company.present? ? "company assigned" : "company cleared"
    email_body = Emails::Inquiry.new.company_update(self, host)
    send_mail(to_addrs, "Print Speak: Inquiry #{message}", email_body) if to_addrs.present?
  end

  def send_estimate_assign_update_email(host, changing_user = nil, estimate = nil, type)
    return unless inquiry_send_email_allowed?("send_estimate_assign_update_email")
    to_addrs = get_email_addresses(changing_user)
    email_body = Emails::Inquiry.new.estimate_assigned(self, host, estimate, type)
    send_mail(to_addrs, "Print Speak: Inquiry estimate ##{estimate.invoice_number} #{type}", email_body) if to_addrs.present?
  end

  def send_order_assign_update_email(host, changing_user = nil, order = nil, type)
    return unless inquiry_send_email_allowed?("send_order_assign_update_email")
    to_addrs = get_email_addresses(changing_user)
    email_body = Emails::Inquiry.new.order_assigned(self, host, order, type)
    send_mail(to_addrs, "Print Speak: Inquiry order ##{order.invoice_number} #{type}", email_body) if to_addrs.present?
  end

  def send_shipment_assign_update_email(host, changing_user = nil, shipment = nil, type)
    return unless inquiry_send_email_allowed?("send_shipment_assign_update_email")
    to_addrs = get_email_addresses(changing_user)
    email_body = Emails::Inquiry.new.shipment_assigned(self, host, shipment, type)
    send_mail(to_addrs, "Print Speak: Inquiry shipment ##{shipment.courier_tracking} #{type}", email_body) if to_addrs.present?
  end

  def send_sale_assign_update_email(host, changing_user = nil, sale = nil, type)
    return unless inquiry_send_email_allowed?("send_sale_assign_update_email")
    to_addrs = get_email_addresses(changing_user)
    email_body = Emails::Inquiry.new.sale_assigned(self, host, sale, type)
    send_mail(to_addrs, "Print Speak: Inquiry sale ##{sale.invoice_number} #{type}", email_body) if to_addrs.present?
  end

  def send_status_update_email(host, changing_user = nil)
    return unless inquiry_send_email_allowed?("send_status_update_email")
    to_addrs = get_email_addresses(changing_user)
    email_body = Emails::Inquiry.new.status_update(self, host)
    send_mail(to_addrs, "Print Speak: Inquiry status changed", email_body) if to_addrs.present?
  end

  def send_inquiry_update_email(host, changing_user = nil)
    return unless inquiry_send_email_allowed?("send_inquiry_update_email")

    to_addrs = get_email_addresses(changing_user)
    email_body = Emails::Inquiry.new.inquiry_update(self, host)
    send_mail(to_addrs, "Print Speak: Inquiry updated", email_body) if to_addrs.present?
  end

  def send_call_created_email(host, changing_user = nil)
    return unless inquiry_send_email_allowed?("send_call_created_email")
    to_addrs = get_email_addresses(changing_user)
    email_body = Emails::Inquiry.new.call_created(self, host)
    send_mail(to_addrs, "Print Speak: Inquiry Call added", email_body) if to_addrs.present?
  end

  def send_note_created_email(host, changing_user = nil)
    return unless inquiry_send_email_allowed?("send_note_created_email")

    to_addrs = get_email_addresses(changing_user)
    email_body = Emails::Inquiry.new.note_created(self, host)
    send_mail(to_addrs, "Print Speak: Inquiry Note added", email_body) if to_addrs.present?
  end

  def send_mail(addresses, email_subject, email_body, source_email = "support@printspeak.com")
    Thread.new {
      Email.ses_send(addresses, email_subject, email_body, source_email)
      ActiveRecord::Base.clear_active_connections!
    }
  end

  def assets
    assets_array = []
    Asset.where(context_type: "Inquiry", context_id: id, tenant_id: tenant_id).each do |asset|
      assets_array << asset.presigned_url(false)
    end
    assets_array
  end

  def platform_id
    nil
  end

  def invoices
    Invoice.where(tenant: tenant, inquiry_id: id)
  end

  def estimates
    Estimate.where(tenant: tenant, inquiry_id: id)
  end

  def shipments
    Shipment.where(tenant: tenant, inquiry_id: id)
  end

  def aggregated_tasks
    Task.where(tenant: tenant, taskable_type: "Inquiry", taskable_id: id).order(created_at: :asc)
  end

  def aggregated_phone_calls
    PhoneCall.where(tenant: tenant, phoneable_type: "Inquiry", phoneable_id: id).order(created_at: :asc)
  end

  def aggregated_notes
    Note.where(tenant: tenant, context_type: "Inquiry", context_id: id).order("created_at DESC, id DESC")
  end

  def aggregated_meetings
    Meeting.where(tenant: tenant, context_type: "Inquiry", context_id: id).order(created_at: :asc)
  end

  def get_email_addresses(changing_user)
    to_addrs = []

    # IF USER IS NOT NIL AND DIFFERENT THAN CURRENT USER
    if not_self_assigned_user?(changing_user)
      to_addrs << test_mode_if_required(user.tenant_email(tenant))
    end
    # APPEND EMAILS FROM SELECTED NOTIFICATION IDS
    to_addrs = add_emails_from_notifications(to_addrs)

    to_addrs if to_addrs.count.positive?
  end

  private

  def test_mode_if_required(email_address)
    if Rails.env.production?
      email_address
    else
      "emailtest@printspeak.com"
    end
  end

  def add_emails_from_notifications(to_addrs)
    tenant.visible_users.where(id: notification_ids).each do |notification_user|
      to_addrs << test_mode_if_required(notification_user.email) unless notification_user.email.blank?
    end
    to_addrs
  end

  def not_self_assigned_user?(changing_user)
    user.present? && changing_user.present? && !test_mode_if_required(user.tenant_email(tenant)).blank? && (changing_user.try(:id) != user.try(:id))
  end

  def inquiry_send_email_allowed?(context)
    tenant.inquiry_notifications.nil? || !tenant.inquiry_notifications.nil? && tenant.inquiry_notifications.include?(context)
  end

  def self.platform_identifier(tenant)
    if Platform.is_printsmith?(tenant)
      if tenant.enterprise.id == 3 && RegionConfig.get_value("region") == "us"
        Inquiry.inquiry_identifiers.reject { |k, v| ["Shipment Request", "General", "Logistica", "e-link", "Web Services", "Touch", "Address", "Spedizioni-imballaggio", "Printing-Marketing", "E-commerce", "SafeValue"].include?(k) }
      else
        Inquiry.inquiry_identifiers.reject { |k, v| ["Shipment Request", "General", "Logistica", "e-link", "Web Services", "Touch", "Address", "Spedizioni-imballaggio", "Printing-Marketing", "E-commerce", "SafeValue", "1M Project"].include?(k) }
      end
    elsif Platform.is_mbe?(tenant)
      Inquiry.inquiry_identifiers.reject { |k, v| ["Quote Request", "Send a file", "Contact us", "1M Project"].include?(k) }
    else
      Inquiry.inquiry_identifiers
    end
  end
end
