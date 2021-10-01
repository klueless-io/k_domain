# frozen_string_literal: true

class ContactGroup < ActiveRecord::Base
  has_and_belongs_to_many :contacts
  belongs_to :tenant
  belongs_to :company
end
