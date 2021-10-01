# frozen_string_literal: true

class CampaignCount < ActiveRecord::Base
  belongs_to :campaign
  belongs_to :tenant
end
