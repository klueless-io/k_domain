class OrderStats < Stats
  def initialize(tenant_id, start_date, end_date, current)
    super # give us: @tenant_id, @start_date, @end_date
    @all_orders = Order.for_tenant(@tenant_id).for_dates(@start_date, @end_date)
    @tenant = Tenant.find(tenant_id)
    @date_helper = DateHelper.new(@start_date, @end_date, @tenant)

    @financial_year = FinancialYear.new(@tenant)
  end

  # Month to Yesterday
  def mty
    if @start_date == @end_date
      @all_orders.where(ordered_date: @start_date..@end_date)
    else
      @all_orders.where(ordered_date: @start_date..@end_date - 1.day)
    end
  end

  def mtd
    @all_orders.where(ordered_date: @start_date..@end_date)
  end

  def ytd
    @all_orders.where(ordered_date: @financial_year.start(@start_date)..@end_date)
  end

  def ly_ytd
    @all_orders.where(ordered_date: @financial_year.ly_start(@start_date)..(@end_date - 1.year))
  end

  def due_today
    start_of_day = Time.now.in_time_zone(@tenant.time_zone).beginning_of_day.utc
    end_of_day = Time.now.in_time_zone(@tenant.time_zone).end_of_day.utc

    @all_orders = Order.for_tenant(@tenant_id).where("on_pending_list = 'TRUE' and wanted_by >= ? and wanted_by <= ? and completed = FALSE", start_of_day, end_of_day)
  end

  def due_by_eom
    @orders = Order.for_tenant(@tenant_id)
    @orders = @orders.where("wanted_by < (?) and on_pending_list = TRUE and pickup_date is NULL and completed = FALSE", @start_date.in_time_zone(@tenant.time_zone).end_of_month)
    @orders
  end

  def largest
    mtd.order("grand_total DESC").first
  end

  def mtd_avg_order_value
    mtd.sum(:grand_total) / mtd.count
  end

  def grouped_by_date
    Chart.group_by_date(mtd, @start_date, @end_date, @tenant)
  end

  def cumulative_grouped_by_date
    Chart.cumulative_grouped_by_date(mtd, @start_date, @end_date, "ordered_date", @tenant)
  end

  def daily_orders
    Order.for_tenant(@tenant_id).for_dates(@start_date, (@end_date)).sum(:grand_total) / (@date_helper.trading_days_gone + 1)
  end

  def total_cost
    @all_orders.present? ? @all_orders.sum(:total_cost) : 0
  end

  def grand_total_inc_tax
    @all_orders.present? ? @all_orders.sum(:grand_total_inc_tax) : 0
  end
end
