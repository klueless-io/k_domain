# frozen_string_literal: true

class BusinessPlan < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  has_many :business_plan_sales_investments
  has_many :business_plan_marketing_activities
end
