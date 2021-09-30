# frozen_string_literal: true

class ContactListCount < ActiveRecord::Base
  belongs_to :contact_list
  belongs_to :tenant
end
