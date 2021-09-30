# frozen_string_literal: true

class HolidayState < ActiveRecord::Base
  belongs_to :holidays
  belongs_to :country_states
end
