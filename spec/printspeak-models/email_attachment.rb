# frozen_string_literal: true

class EmailAttachment < ActiveRecord::Base
  establish_connection "mail_#{Rails.env}".to_sym

  belongs_to :email_message
  has_one :email_inbox, through: :email_message

  alias_attribute :message, :email_message
  alias_attribute :inbox, :email_inbox

  def url
    Rails.application.routes.url_helpers.url_for(controller: :emails, action: :attachment, id: id, only_path: true)
  end
end
