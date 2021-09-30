# frozen_string_literal: true

class EmailLabel < ActiveRecord::Base
  establish_connection "mail_#{Rails.env}".to_sym

  has_and_belongs_to_many :email_messages, -> { uniq }
  belongs_to :email_inbox

  alias_attribute :inbox, :email_inbox
  alias_attribute :messages, :email_messages
end
