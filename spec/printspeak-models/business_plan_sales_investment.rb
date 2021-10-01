# frozen_string_literal: true
class BusinessPlanSalesInvestment < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  belongs_to :business_plan
  belongs_to :user
end
