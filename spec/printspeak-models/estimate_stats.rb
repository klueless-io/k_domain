# frozen_string_literal: true

class EstimateStats < Stats
  def initialize(tenant_id, start_date, end_date, current)
    super # give us: @tenant_id, @start_date, @end_date
    @estimates = Estimate.for_tenant(@tenant_id).for_dates(@start_date, @end_date)
    @tenant = Tenant.find(tenant_id)
    @date_helper = DateHelper.new(@start_date, @end_date, Tenant.find(tenant_id))
  end

  def won_estimates
    # WON ESTIMATES NEED TO BE BASED ON OFF_PENDING_DATE
    Estimate.for_tenant(@tenant_id).where(off_pending_date: @start_date..@end_date).where(status: "Won")
  end

  def grouped_by_date
    Chart.group_by_date(@estimates, @start_date, @end_date, @tenant)
  end

  def won_grouped_by_date
    Chart.group_by_date(won_estimates, @start_date, @end_date, "off_pending_date", @tenant)
  end

  def cumulative_grouped_by_date
    Chart.cumulative_grouped_by_date(@estimates, @start_date, @end_date, @tenant)
  end

  def won_cumulative_grouped_by_date
    Chart.cumulative_grouped_by_date(won_estimates, @start_date, @end_date, "off_pending_date", @tenant)
  end

  def total_cost
    @estimates.present? ? @estimates.sum("total_cost") : 0
  end

  def grand_total_inc_tax
    @estimates.present? ? @estimates.sum("grand_total_inc_tax") : 0
  end
end
