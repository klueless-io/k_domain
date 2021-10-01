class Email < ActiveRecord::Base
  belongs_to :user
  belongs_to :sending_as_user, class_name: "User", foreign_key: :sending_as_user_id
  belongs_to :tenant
  belongs_to :context, polymorphic: true
  has_and_belongs_to_many :email_tags
  has_and_belongs_to_many :trackers, -> { uniq }
  has_many :hits, through: :trackers



  attr_accessor :from_name
  attr_accessor :to_name

  alias_attribute :date, :created_at
  alias_attribute :from_address, :from
  alias_attribute :to_address, :to

  def to_email_message
    EmailMessage.new(
      sent_id: id,
      subject: subject,
      html: body,
      text: body,
      message_id: "invalid",
      date: created_at,
      from_addresses: [from],
      from_names: [""],
      to_addresses: to.try(:split, ",").try(:map) { |s| "#{s.squish.downcase}" },
      to_names: to.try(:split, ",").try(:map) { |s| "" },
      cc_addresses: cc.try(:split, ",").try(:map) { |s| "#{s.squish.downcase}" },
      cc_names: cc.try(:split, ",").try(:map) { |s| "" },
      failed: check_failed
    )
  end

  def check_failed
    processed == true && message_id.blank? && email_id.blank? && created_at >= DateTime.new(2019, 3, 25)
  end

  def send_email
    if !processed && (error_backoff.nil? || error_backoff < Time.now)
      from_user = sending_as_user || user
      if !from.blank? && from.include?("@")
        from_addr = nil
        begin
          from_addr = Mail::Address.new("#{from_user.email_name} <#{from}>").format
        rescue Mail::Field::ParseError
          report_send_error("Failed to parse From address", true)
          return
        end

        attachments_ready = true
        attachment_error = nil
        pending_attachments = PendingAttachment.where(uuid: attachment_uuid)
        pending_attachments.each do |pending_attachment|
          attachment_error = pending_attachment.error if attachment_error.blank?
          attachments_ready = false if !pending_attachment.complete
        end

        if !attachment_error.nil?
          report_send_error("Attachment: #{attachment_error}", true)
          return
        end

        if !attachments_ready
          return
        end

        encoded_mail, message_id = Email.create_email_message(
          to: to,
          from: from_addr,
          cc: cc,
          bcc: bcc,
          subject: subject,
          body: body.dup,
          attachment_uuid: attachment_uuid
        )

        if encoded_mail.nil?
          report_send_error("Failed to create email message", true)
          return
        end

        begin
          Timeout::timeout(120) do
            if tenant.use_smtp
              send_smtp(from_user, encoded_mail, message_id)
            else
              send_gmail(from_user, encoded_mail, message_id)
            end
          end
        rescue Timeout::Error
          report_send_error("Email took too long to send", false)
        end
      else
        report_send_error("From address invalid", true)
      end
    end
  end

  def send_smtp(from_user, encoded_mail, message_id)
    creds = from_user.email_creds(tenant)
    return if creds.smtp_server.blank? || creds.smtp_username.blank? || creds.smtp_password.blank? || creds.smtp_port.nil?
    begin
      from_addrs = Email.parse_email_addresses(from)
      to_addrs = Email.parse_email_addresses(to)
      cc_addrs = Email.parse_email_addresses(cc)
      bcc_addrs = Email.parse_email_addresses(bcc)
      dest_addrs = (to_addrs + cc_addrs + bcc_addrs)
      dest_addrs = (dest_addrs + from_addrs) if tenant.auto_self_bcc
      dest_addrs = dest_addrs.uniq.reject(&:blank?)
    rescue StandardError
      report_send_error("Invalid address", true)
    end
    begin
      smtp_client = Net::SMTP.new(creds.smtp_server, creds.smtp_port)
      if creds.smtp_port == 465
        smtp_client.enable_ssl
      else
        smtp_client.enable_starttls_auto
      end
      smtp_client.start("localhost", creds.smtp_username, creds.smtp_password, :login) do |smtp|
        smtp.sendmail(encoded_mail, from, dest_addrs)
      end
      self.processed = true
      self.message_id = message_id
      save
      Email.cleanup_attachment_uuid(attachment_uuid, id)
    rescue Exception => e
      report_send_error(e)
    end
  end

  def send_gmail(from_user, encoded_mail, message_id)
    if from_user.token.blank?
      report_send_error("Unauthorized", true)
      return
    end

    require "google/apis/gmail_v1"
    gmail = Google::Apis::GmailV1::GmailService.new
    gmail.authorization = from_user.token.authorization
    unless bcc.blank?
      encoded_mail.prepend "Bcc: #{bcc}\n"
    end

    begin
      result = gmail.send_user_message("me", nil, upload_source: StringIO.new(encoded_mail), content_type: "message/rfc822")
      self.email_id = result.id
      self.thread_id = result.thread_id
      self.message_id = message_id
      self.processed = true
      save
      Email.cleanup_attachment_uuid(attachment_uuid, id)
    rescue Google::Apis::ClientError => client_error
      report_send_error(client_error, true)
    rescue Exception => e
      Token.where(user_id: from_user.id).update_all(expires_at: Time.now)
      report_send_error(e)
    end
  end

  def report_send_error(error_message, permanent=false)
    self.processed = permanent
    self.failed_reason = error_message
    notify = false
    if error_backoff.nil?
      self.error_backoff = Time.now + 30.seconds
    else
      notify = true if created_at >= 15.minutes.ago
      self.error_backoff = Time.now + 5.minutes
    end
    save
    if notify
      ::Honeybadger.notify(
        error_class: "Failed to process outbound email",
        error_message: error_message,
        parameters: {
          email: {
            id: id
          },
          tenant: {
            id: tenant.id,
            name: tenant.display_name
          }
        }
      )
    end
  end

  def friendly_error_message
    result = "None"

    if !failed_reason.blank?
      result = "Unknown"
      if self.failed_reason = "Email took too long to send"
        result = failed_reason
      elsif failed_reason =~ /Attachment:/i
        result = failed_reason
      elsif failed_reason =~ /invalid\saddress/i
        result = "Invalid Address"
      elsif failed_reason =~ /invalid/i
        result = "Invalid"
      elsif failed_reason =~ /uploadTooLarge/i
        result = "Attachments Too Large"
      elsif failed_reason =~ /authorization\sfailed/i || failed_reason =~ /authentication\sunsuccessfu/i
        result = "Unauthorized"
      end
    end

    result
  end

  def attachment_assets
    Asset.where(tenant_id: tenant.id, category: "Email Attachment", context_type: "Email", context_id: id)
  end

  def self.cleanup_attachment_uuid(attachment_uuid, email_id)
    pending_attachments = PendingAttachment.where(uuid: attachment_uuid)
    pending_attachments.each do |pending_attachment|
      asset = Asset.where(context_type: "PendingAttachment", context_id: pending_attachment.id).first
      if asset
        asset.update_attributes(context_type: "Email", context_id: email_id)
      end
      pending_attachment.destroy
    end
  end

  def self.create_email_message(to: nil, from: nil, cc: nil, bcc: nil, subject: nil, body: nil, attachment_uuid: nil)
    return nil if to.blank? || from.blank?

    msg = Mail.new
    subject = "" if subject.nil?
    body = "" if body.nil?

    pending_attachments = []
    new_attachments = []
    if !attachment_uuid.blank?
      pending_attachments = PendingAttachment.where(uuid: attachment_uuid)
      pending_attachments.each do |pending_attachment|
        failed = false
        asset = Asset.where(context_type: "PendingAttachment", context_id: pending_attachment.id).first
        if asset
          file_contents = nil
          if pending_attachment.inline
            begin
              file_contents = open(URI.encode(asset.url, "[]")).read
            rescue StandardError
              failed = true
            end
          end

          if !failed
            new_attachments << {
              url: asset.tracked_url,
              file_contents: file_contents,
              file_name: asset.file_name
            }
          end
        else
          failed = true
        end

        if failed
          return nil
        end
      end
    end

    if new_attachments.count > 0
      inlined_file_names = []
      hint_text = "<!-- ATTACHMENTS -->"
      pos = body.index(hint_text)
      attachment_text = ""
      attachment_text << "<strong>Attachments</strong><ul>"

      new_attachments.each do |new_attachment|
        attachment_text << %Q{<li><a href="#{new_attachment[:url]}">#{new_attachment[:file_name]}</a></li>}

        if !new_attachment[:file_contents].nil?
          uniq_file_name = new_attachment[:file_name]
          uniq_file_name = %Q{#{inlined_file_names.count}_#{uniq_file_name}} if inlined_file_names.include?(uniq_file_name)
          inlined_file_names << uniq_file_name

          msg.attachments[uniq_file_name] = {
            mime_type: MIME::Types.type_for(new_attachment[:file_name]).first.try(:content_type) || "application/octet-stream",
            content: new_attachment[:file_contents]
          }
        end
      end

      attachment_text << "</ul>"
      if pos.nil?
        body << "<br/><br/>#{attachment_text}"
      else
        body.insert(pos + hint_text.length, attachment_text)
      end
    end

    msg.date = Time.now
    msg.subject = subject
    msg.content_type = "multipart/mixed"
    msg.html_part = Mail::Part.new({
      content_type: "text/html; charset=UTF-8",
      body: body
    })

    msg.to = to
    msg.from = from
    msg.cc = cc unless cc.blank?

    msg.encoded

    msg.header["X-PrintSpeak-Id"] = msg.message_id

    encoded_mail = msg.encoded

    [encoded_mail, msg.message_id]
  end

  def self.clean_email(data)
    data.try(:strip).try(:downcase) || ""
  end

  def self.valid_format?(data)
    !/\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/.match(data).nil?
  end

  def self.valid_rfc822?(data)
    return false if data.blank?
    result = false
    rx = /((?:(?:\r\n)?[ \t])*(?:(?:(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*))*@(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*|(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*)*\<(?:(?:\r\n)?[ \t])*(?:@(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*(?:,@(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*)*:(?:(?:\r\n)?[ \t])*)?(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*))*@(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*\>(?:(?:\r\n)?[ \t])*)|(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*)*:(?:(?:\r\n)?[ \t])*(?:(?:(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*))*@(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*|(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*)*\<(?:(?:\r\n)?[ \t])*(?:@(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*(?:,@(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*)*:(?:(?:\r\n)?[ \t])*)?(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*))*@(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*\>(?:(?:\r\n)?[ \t])*)(?:,\s*(?:(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*))*@(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*|(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*)*\<(?:(?:\r\n)?[ \t])*(?:@(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*(?:,@(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*)*:(?:(?:\r\n)?[ \t])*)?(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|"(?:[^\"\r\\]|\\.|(?:(?:\r\n)?[ \t]))*"(?:(?:\r\n)?[ \t])*))*@(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*)(?:\.(?:(?:\r\n)?[ \t])*(?:[^()<>@,;:\\".\[\] \000-\031]+(?:(?:(?:\r\n)?[ \t])+|\Z|(?=[\["()<>@,;:\\".\[\]]))|\[([^\[\]\r\\]|\\.)*\](?:(?:\r\n)?[ \t])*))*\>(?:(?:\r\n)?[ \t])*))*)?;\s*))/
    data = data.gsub(/\(.+?\)/, "").strip
    cleaned = data.gsub(";", ",").gsub(",,", ",").chomp(",")
    built = ""
    first = true
    data.scan(rx) do |match|
      address = match.first
      if rx.match(address)
        squished_address = address.gsub(/\s+/, "")
        if /[^\s<]+@[^\s>]+/.match(squished_address).to_s == /[^\s<]+@[^\s>]+/.match(address).to_s
          built << "," if !first
          built << "#{address}"
          first = false
        end
      end
    end
    if cleaned == built
      result = true
    else
    end
    result
  end

  # def self.scan_test
  #   Email.select('emails.id, emails.email_id, emails.cc').where("cc is not null and cc != ''").where(processed: true).find_each do |email|
  #     valid = Email.valid_rfc822?(email.cc)

  #     if email.email_id.blank? != !valid
  #       puts "MISMATCH ID: #{email.id} HAS_EMAIL_ID: #{!email.email_id.blank?} VALID: #{valid}   '#{email.cc}'"
  #     end
  #   end
  # end

  def self.ses_send(addresses, subject, body, source_email = "support@printspeak.com")
    return if addresses.count <= 0
    begin
      ses = Aws::SES::Client.new(region: RegionConfig.require_value("aws_region"), access_key_id: Rails.application.secrets.aws_access_key_id_email, secret_access_key: Rails.application.secrets.aws_secret_access_key_email)
      addresses = addresses.uniq
      addresses.each do |address|
        next if !Email.valid_rfc822?(address)
        to_addr = address
        to_addr = "emailtest@printspeak.com" if Rails.env.staging?
        ses.send_email(
        {
          source: source_email,
          destination: {
            to_addresses: [to_addr]
          },
          message: {
            subject: {
              data: subject
            },
            body: {
              text: {
                data: ""
              },
              html: {
                data: body
              },
            },
          }
        })
      end
    rescue StandardError => e
      Honeybadger.notify(
        error_class: "SES Send Failed",
        error_message: e.message,
        backtrace: e.backtrace,
        parameters: {
          from: source_email,
          to: addresses,
          subject: subject,
          body: body
        }
      )
    end
  end

  def self.parse_email_addresses(address_string)
    result = []

    if !address_string.blank?
      addresses =  address_string.split(/,(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)/)
      addresses.each do |address|
        parsed_address = Mail::Address.new(address.squish)
        result << parsed_address.address
      end
    end

    result
  end

  def self.send_unprocessed_emails(tenant)
    limit = 5
    Email.where(tenant: tenant, processed: false).order("bulk ASC NULLS FIRST, created_at ASC").each do |email|
      break if limit <= 0
      email.send_email
      limit = limit - 1 if email.processed
      WorkerDaemon.heartbeat
    end
  end

  def self.printspeak_template(body)
    %Q{
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
          <meta name="viewport" content="width=device-width">
          <meta name="format-detection" content="address=no;email=no;telephone=no">
        </head>
        <body leftmargin="0" marginwidth="0" topmargin="0" marginheight="0" offset="0" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;margin-top: 0;margin-left: 0;margin-right: 0;margin-bottom: 0;padding-top: 25px;padding-bottom: 25px;padding-left: 0;padding-right: 0;height: 100%;width: 100%;background-color: #efefef;">
          <table id="container" style="background: #ffffff;margin: 0px auto;font-size: 14px;width: 500px;border-radius: 5px; font-family: 'Helvetica Neue', Arial, Verdana;overflow: hidden;line-height: 125% !important;">
            <thead>
              <tr style="background: #3695d5;width: 100%;display: block;color: #fff;font-size: 16px;white-space: nowrap;margin: -2px -2px 0px -2px;padding-right: 4px;">
                <td style="padding: 5px !important;border: none;">
                  <img src="http://public.printspeak.com/images/logo-white.png" alt="" style="width:50px; vertical-align: middle"> Print Speak
                </td>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td style="padding: 20px;border: none;">
                  #{body}
                </td>
              </tr>
            </tbody>
          </table>
        </body>
      </html>
    }
  end
end
