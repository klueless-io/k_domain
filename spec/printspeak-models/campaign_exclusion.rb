# frozen_string_literal: true

class CampaignExclusion < ActiveRecord::Base
  belongs_to :contact
  belongs_to :campaign
end
