# frozen_string_literal: true

class ProspectStatusItem < ActiveRecord::Base
  default_scope { order(position: :asc) }
  acts_as_list scope: %i[lead_type_id prospect_status_id enterprise_id]

  enum item_type: {
    "Email": 0,
    "Call": 1,
    "Task": 2,
    "Meeting": 3
  }

  belongs_to :enterprise
  belongs_to :prospect_status
  belongs_to :lead_type
  belongs_to :email_template
  has_many :prospect_status_item_contacts

  # has_one :prospect_status_item_contact, -> (contact) { where(contact_id: contact.id) }

  validates :name, presence: { message: "Item name can't be blank (required)." }
  validates :name, length: { maximum: 250 }

  scope :by_contact, -> (contact) {
    joins("LEFT JOIN prospect_status_item_contacts ON prospect_status_item_contacts.prospect_status_item_id = prospect_status_items.id AND prospect_status_item_contacts.contact_id = #{ contact.id }")
  }

  def user
    User.unscoped.where(id: user_id).try(:first) unless user_id.nil?
  end

  def prospect_status_item_contact(contact_id)
    ProspectStatusItemContact.where(prospect_status_item_id: id, contact_id: contact_id).first
  end
end
