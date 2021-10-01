# frozen_string_literal: true

class CampaignCalendarEntry < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :user
  belongs_to :campaign
  belongs_to :calendar_entry
end
