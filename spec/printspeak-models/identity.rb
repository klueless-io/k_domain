class Identity < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  has_many :locations
  has_many :campaigns

  def check_email_status(new_email = nil)
    email = new_email.nil? ? email_marketing : new_email

    if email.blank?
      self.email_status = nil
      save
      return "No Email"
    end

    domain = email.split("@").last
    base_domain = PublicSuffix.domain(domain)

    result = ""
    set_topics = false
    begin
      if Platform.is_mbe?(tenant)
        resp = ses.get_identity_verification_attributes({identities: [email]})
      else
        resp = ses.get_identity_verification_attributes({identities: [email, domain, base_domain]})
      end

      if resp
        if resp.verification_attributes[domain].try(:verification_status) == "Success" || resp.verification_attributes[base_domain].try(:verification_status) == "Success"
          result = "Success"
        elsif resp.verification_attributes[email].try(:verification_status) == "Success"
          result = "Success"
          set_topics = true
        else
          result = "Pending" if resp.verification_attributes[email].try(:verification_status) == "Pending" ||
                                resp.verification_attributes[domain].try(:verification_status) == "Pending" ||
                                resp.verification_attributes[base_domain].try(:verification_status) == "Pending"
        end
      end
    rescue StandardError
    end

    if result == "Success"
      if set_topics
        topic = "arn:aws:sns:us-west-2:016696148259:ses_sqs_staging" if Rails.env.staging?
        topic = RegionConfig.require_value("ses_sns_topic") if Rails.env.production? || Rails.env.worker?
        set_sns_topics(email, topic)
      end
      self.last_validated = Time.now
      self.email_status = "Validated"
    elsif result == "Pending"
      self.email_status = "Pending"
      self.last_validated = nil
    else
      self.email_status = nil
      self.last_validated = nil
    end
    save

    result
  end

  def set_sns_topics(email, topic)
    begin
      resp = ses.set_identity_notification_topic({ identity: email, notification_type: "Delivery", sns_topic: topic })
      resp = ses.set_identity_notification_topic({ identity: email, notification_type: "Bounce", sns_topic: topic })
      resp = ses.set_identity_notification_topic({ identity: email, notification_type: "Complaint", sns_topic: topic })
    rescue StandardError => e
      Honeybadger.notify(e, context: {
        tenant: tenant,
        email: email,
        topic: topic,
      })
    end
    nil
  end

  def was_valid?
    last_validated != nil
  end

  def sent_verification_email?
    return false if email_marketing.blank?
    result = false

    begin
      resp = ses.verify_email_identity({email_address: "#{email_marketing}"})

      if resp.successful?
        result = true
        self.email_status = "Pending"
      else
        result = false
      end
      save
    rescue StandardError
    end

    result
  end

  def send_email(dest_addr, subject, body, bcc_addrs = [])
    # return nil unless valid_ses?

    result = nil
    # return SecureRandom.uuid # Uncomment if you want to prevent all sending for debugging purposes

    from_addr = marketing_name.blank? ? email_marketing : "#{marketing_name} <#{email_marketing}>"
    begin
      resp = ses.send_email({
        source: from_addr,
        destination: {
          bcc_addresses: bcc_addrs,
          to_addresses: [dest_addr]
          },
        message: {
            subject: {
              data: subject
              },
            body: {
                html: {
                  data: body
                  },
                  },
                }
                })
      if resp
        result = resp.message_id
      end
    rescue StandardError
    end

    result
  end

  private

  def ses
    @ses ||= Aws::SES::Client.new(region: RegionConfig.require_value("aws_region"), access_key_id: Rails.application.secrets.aws_access_key_id_email, secret_access_key: Rails.application.secrets.aws_secret_access_key_email)
  end
end
