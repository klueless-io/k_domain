# frozen_string_literal: true

class ContactListExclusion < ActiveRecord::Base
  belongs_to :contact
  belongs_to :contact_list
  belongs_to :tenant
end
