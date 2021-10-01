class Activity < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :contact
  belongs_to :company
  belongs_to :estimate
  belongs_to :invoice
  belongs_to :order
  belongs_to :sale
  belongs_to :phone_call
  belongs_to :task
  belongs_to :email
  belongs_to :comment
  belongs_to :tracker
  belongs_to :note
  belongs_to :shipment
  belongs_to :campaign
  belongs_to :campaign_message
  belongs_to :portal_comment
  belongs_to :comment
  belongs_to :inquiry
  default_scope { where(hide: false, deleted: false).order("activities.source_created_at DESC NULLS LAST") }
  before_create :update_source_created_at
  before_save :update_source_created_at
  after_create :update_last_contact
  after_save :update_last_contact

  def user
    User.unscoped.where(id: user_id).try(:first) unless user_id.nil?
  end

  def estimate
    Estimate.unscoped.where(tenant_id: tenant_id).where(id: estimate_id).try(:first) unless estimate_id.nil?
  end

  def invoice
    Invoice.unscoped.where(tenant_id: tenant_id).where(id: invoice_id).try(:first) unless invoice_id.nil?
  end

  def email_message
    msg = nil
    if email_message_id
      msg = EmailMessage.where(id: email_message_id).first
      if msg.nil?
        self.deleted = true
        save
      end
    elsif !email.try(:message_id).blank?
      msg = EmailMessage.where(internal_message_id: email.message_id).first
    end
    msg
  end

  def self.add_contextual_attribute(attribs, context)
    if context
      key = (context.class.superclass == Invoice) ? "invoice" : context.class.to_s.downcase.to_s
      value = context
      attribs[key] = value
    end
    attribs
  end

  def self.default_excluded_activities
    %w[campaign_message campaign_opened]
  end

  def email_attachment_assets
    Asset.where(tenant_id: tenant.id, category: "Email Attachment", context_type: "Email", context_id: email_id)
  end

  private

  def update_source_created_at
    self.source_created_at = created_at if source_created_at.nil?
  end

  def update_last_contact
    if %w[email phone_call meeting_completed].include?(activity_for)
      meeting = nil
      target_contact = contact
      target_company = company

      if activity_for == "meeting_completed"
        meeting = Meeting.where(id: meeting_id).first
        if meeting
          if meeting.context.class == Contact
            target_contact = meeting.context
          elsif meeting.context.class == Company
            target_company = meeting.context
          else
            target_contact = meeting.context.try(:contact)
          end
        end
      end


      if !target_contact.nil?
        did_update = false
        if activity_for == "email"
          if !email_id.nil?
            if target_contact.last_email_sent.nil? || (!target_contact.last_email_sent.nil? && source_created_at > target_contact.last_email_sent)
              target_contact.update(last_email_sent: source_created_at)
              did_update = true
            end
          else
            if target_contact.last_email_received.nil? || (!target_contact.last_email_received.nil? && source_created_at > target_contact.last_email_received)
              target_contact.update(last_email_received: source_created_at)
              did_update = true
            end
          end
        elsif activity_for == "phone_call"
          if !phone_call_id.nil? && (target_contact.last_phone_call.nil? || (!target_contact.last_phone_call.nil? && source_created_at > target_contact.last_phone_call))
            target_contact.update(last_phone_call: source_created_at)
            did_update = true
          end
        elsif activity_for == "meeting_completed"
          if !meeting_id.nil? && (target_contact.last_meeting.nil? || (!target_contact.last_meeting.nil? && source_created_at > target_contact.last_meeting))
            target_contact.update(last_meeting: source_created_at)
            did_update = true
          end
        end
        target_contact.update(last_contact: source_created_at) if did_update && (target_contact.last_contact.nil? || source_created_at > target_contact.last_contact)
      end

      target_company = target_contact.company if target_company.nil? && !target_contact.nil?
      if !target_company.nil?
        did_update = false
        if activity_for == "email"
          if !email_id.nil?
            if target_company.last_email_sent.nil? || (!target_company.last_email_sent.nil? && source_created_at > target_company.last_email_sent)
              company.update(last_email_sent: source_created_at)
              did_update = true
            end
          else
            if target_company.last_email_received.nil? || (!company.last_email_received.nil? && source_created_at > target_company.last_email_received)
              target_company.update(last_email_received: source_created_at)
              did_update = true
            end
          end
        elsif activity_for == "phone_call"
          if !phone_call_id.nil? && (target_company.last_phone_call.nil? || (!target_company.last_phone_call.nil? && source_created_at > target_company.last_phone_call))
            target_company.update(last_phone_call: source_created_at)
            did_update = true
          end
        elsif activity_for == "meeting_completed"
          if !meeting_id.nil? && (target_company.last_meeting.nil? || (!target_company.last_meeting.nil? && source_created_at > target_company.last_meeting))
            target_company.update(last_meeting: source_created_at)
            did_update = true
          end
        end
        target_company.update(last_contact: source_created_at) if did_update && (target_company.last_contact.nil? || source_created_at > target_company.last_contact)
      end
    end
  end
end