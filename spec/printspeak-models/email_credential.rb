class EmailCredential < ActiveRecord::Base
  belongs_to :user
  belongs_to :tenant
  belongs_to :enterprise



  def smtp_server
    credentials["smtp_server"]
  end

  def smtp_port
    credentials["smtp_port"]
  end

  def smtp_username
    credentials["smtp_username"]
  end

  def smtp_password
    credentials["smtp_password"]
  end

  def imap_server
    credentials["imap_server"]
  end

  def imap_port
    credentials["imap_port"]
  end

  def imap_username
    credentials["imap_username"]
  end

  def imap_password
    credentials["imap_password"]
  end

  def valid_smtp?
    return false if platform != "smtp/imap"
    result = true
    result = false if smtp_server.blank? || smtp_username.blank? || smtp_password.blank? || smtp_port.nil?

    begin
      smtp_client = Net::SMTP.new(smtp_server, smtp_port)
      if smtp_port == 465
        smtp_client.enable_ssl
      else
        smtp_client.enable_starttls_auto
      end
      smtp_client.open_timeout = 10
      smtp_client.read_timeout = 10
      smtp_client.start("localhost", smtp_username, smtp_password, :login)
      smtp_client.finish
    rescue StandardError
      result = false
    end

    result
  end

  def valid_imap?
    require "net/imap"
    require "timeout"
    return false if platform != "smtp/imap"
    result = true
    result = false if imap_server.blank? || imap_username.blank? || imap_password.blank? || imap_port.nil?

    begin
      Timeout::timeout(10) do
        imap = nil
        if imap_port != 143
          imap = Net::IMAP.new(imap_server, port: imap_port, ssl: true)
        else
          imap = Net::IMAP.new(imap_server, port: imap_port, ssl: false)
          imap.starttls
        end
        imap.authenticate("PLAIN", imap_username, imap_password)
      end
    rescue StandardError
      result = false
    end

    result
  end
end
