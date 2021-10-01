# frozen_string_literal: true

class CalendarEntryDeletion < ActiveRecord::Base
  belongs_to :user, required: true
  validates :user, presence: { message: "must exist" }
  has_many :tokens, through: :user

  def retry_delete
    if user.delete_calendar_event(calendar_ident, entry_ident, send_updates: send_updates)
      destroy
    end
  end
end
