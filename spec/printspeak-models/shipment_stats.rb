class ShipmentStats < Stats
  attr_reader :shipments

  def initialize(tenant_id, start_date, end_date, current)
    super # give us: @tenant_id, @start_date, @end_date
    @shipments = Shipment.for_tenant(@tenant_id).for_dates(@start_date, @end_date).where(status: %w[CREATED DRAFT_WAYBILL INVOICED])

    @tenant = Tenant.find(@tenant_id)
    @date_helper = DateHelper.new(@start_date, @end_date, @tenant)

    @financial_year = FinancialYear.new(@tenant)
  end

  # Month to Yesterday
  def mty
    if @start_date == @end_date
      @shipments.where(shipment_date: @start_date..@end_date)
    else
      @shipments.where(shipment_date: @start_date..@end_date - 1.day)
    end
  end

  def mtd
    @shipments.where(shipment_date: @start_date..@end_date)
  end

  def ytd
    @shipments.where(shipment_date: @financial_year.start(@start_date)..@end_date)
  end

  def ly_ytd
    @shipments.where(shipment_date: @financial_year.ly_start(@start_date)..(@end_date - 1.year))
  end

  def due_today
    start_of_day = Time.now.in_time_zone(@tenant.time_zone).beginning_of_day.utc
    end_of_day = Time.now.in_time_zone(@tenant.time_zone).end_of_day.utc

    @shipments = Shipment.for_tenant(@tenant_id).where(status: %w[CREATED DRAFT_WAYBILL INVOICED]).where("shipment_date >= ? and shipment_date <= ?", start_of_day, end_of_day)
  end

  def due_by_eom
    @shipments = Shipment.for_tenant(@tenant_id).where(status: %w[CREATED DRAFT_WAYBILL INVOICED])
    @shipments = @shipments.where("shipment_date < (?)", @start_date.in_time_zone(@tenant.time_zone).end_of_month)
    @shipments
  end

  def largest
    mtd.order("grand_total DESC").first
  end

  def mtd_avg_order_value
    mtd.sum(:grand_total) / mtd.count
  end

  def grouped_by_date
    Chart.group_by_date(mtd, @start_date, @end_date, group_on="shipment_date", @tenant)
  end

  def cumulative_grouped_by_date
    Chart.cumulative_grouped_by_date(mtd, @start_date, @end_date, "shipment_date", @tenant)
  end

  def daily_orders
    Shipment.for_tenant(@tenant_id).for_dates(@start_date, (@end_date)).where(status: %w[CREATED DRAFT_WAYBILL INVOICED]).sum(:grand_total) / (@date_helper.trading_days_gone + 1)
  end

  def total_cost
    # @shipments.present? ? @shipments.sum(:total_cost) : 0
  end

  def grand_total
    @shipments.present? ? @shipments.sum(:grand_total) : 0
  end

  def daily_target
    # (BUDGET - ORDERS_UNTIL_YESTERDAY) / ( REMAINING_TRADING_DAYS)
    # eg. (59800 -  17057) / (23 - 10) = 3,288 (default is $2,600)
    shipment_total = mty.sum(:grand_total)
    trading_days = @date_helper.trading_days
    trading_days_left = @date_helper.trading_days_left

    # IF
    # [TARGET <= shipmentS]
    #   OR [DAILY shipment AVG < AVG DAILY BUDGET]
    #     OR [TRADING_DAYS_LEFT is 0]
    if target
      # SET DEFAULT = BUDGET/TRADING DAYS
      if ((target <= shipment_total) or ((target - shipment_total) / trading_days_left) <= (target / trading_days)) or (trading_days_left == 0)
         target / trading_days
      else
         ((target - shipment_total) / trading_days_left)
      end
    else
      nil
    end
  end

  def daily_target_percentage
    if daily_target
     (daily_shipments / daily_target) * 100
    else
      nil
    end
  end

  def goal_percentage
    target == 0 ? 0 : (shipments / target) * 100
  end

  def daily_shipments
    Shipment.for_tenant(@tenant_id).for_dates(@start_date, (@end_date)).sum(:grand_total) / (@date_helper.trading_days_gone + 1)
  end

  def target(year = nil)
    year ||= @tenant.financial_year_from_date(@end_date)
    # return year
    # @tenant = Tenant.find( @tenant_id )
    budget = @tenant.current_budget(year)

    if budget
      # GET MONTH DATE (CUSTOM YEAR WITH MONTH (CURRENT))
      month_date = "#{@tenant.financial_year_of(@end_date.month, year)}-#{@end_date.month}-01"
      budget_m = budget.budget_months.find_by(month_date: month_date).try(:total) || 0
    else
      0
    end
  end
end
