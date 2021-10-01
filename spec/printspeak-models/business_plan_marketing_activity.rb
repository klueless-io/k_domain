# frozen_string_literal: true
class BusinessPlanMarketingActivity < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :business_plan
  belongs_to :enterprise
end
