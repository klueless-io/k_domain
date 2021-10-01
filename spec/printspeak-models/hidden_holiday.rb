# frozen_string_literal: true

class HiddenHoliday < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :holiday
end
