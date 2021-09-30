# frozen_string_literal: true

class EmailInboxWrite < ActiveRecord::Base
  establish_connection "mail_#{Rails.env}".to_sym
  self.table_name = "inboxes"
end
