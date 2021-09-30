# frozen_string_literal: true

class MeetingAttendee < ActiveRecord::Base
  # This enum has a misspelling
  enum status: %i[unknown sent received accepted rejected]
  belongs_to :user
  belongs_to :contact
  belongs_to :meeting, inverse_of: :attendees
  delegate :tenant, to: :meeting, allow_nil: true

  def address
    result = nil
    if user
      result = user.email
    elsif contact
      result = contact.email
    else
      result = email_address
    end
    result
  end

  def display_name
    result = nil
    if user
      result = user.display_name
    elsif contact
      result = contact.full_name
    else
      result = email_address
    end
    result
  end
end
