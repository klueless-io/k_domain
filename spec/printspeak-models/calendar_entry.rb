# frozen_string_literal: true

class CalendarEntry < ActiveRecord::Base
  belongs_to :calendar, required: true
  validates :calendar, presence: { message: "must exist" }
end
