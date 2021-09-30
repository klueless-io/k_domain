# frozen_string_literal: true

class Budget < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  has_many :budget_months, dependent: :destroy

  validate :ensure_valid_financial_year, on: :create

  def find_budget_month(month_number)
    if budget_months.present?
      month_date = "#{tenant.financial_year_of(month_number, financial_year)}-#{month_number}-01"
      budget_months.where(month_date: month_date).first
    end
  end

  def remaining_yearly_budget(current_month = Time.now.month)
    months = tenant.financial_months
    months = months[months.find_index(current_month)..-1]
    total = 0
    months.each do |month|
      month_date = "#{tenant.financial_year_of(month, financial_year)}-#{month}-01".to_date
      budget_month = budget_months.find_by(month_date: month_date)
      total += budget_month.nil? || budget_month.total.nil? ? 0 : budget_month.total
    end
    total
  end

  class << self
    def current_financial_year
      if Time.now.month < 7
        Time.now.year
      else
        Time.now.year + 1
      end
    end
  end

  private

  def ensure_valid_financial_year
    existing_budget_for_year = Budget.where(tenant_id: tenant_id, financial_year: financial_year).first
    if existing_budget_for_year
      errors.add(:base, "Budget for #{financial_year} already exists.")
    end
  end
end
