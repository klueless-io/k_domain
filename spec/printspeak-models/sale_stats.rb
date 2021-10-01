class SaleStats < Stats
  attr_reader :current

  def initialize(tenant_id, start_date, end_date, current)
    super # give us: @tenant_id, @start_date, @end_date, @current
    @tenant       = Tenant.find(tenant_id)
    @sales        = Sale.for_tenant(@tenant_id).for_dates(@start_date, @end_date).invoiced(Platform.is_mbe?(@tenant))

    @date_helper  = DateHelper.new(@start_date, @end_date, Tenant.find(tenant_id))
    @orders_stats = OrderStats.new(@tenant_id, @start_date, @end_date, current)
  end

  def has_target
    # NOT USING THIS METHOD ACROSS THE APP ????
    # Budget.where('tenant_id = (?) and year = (?) and month = (?)', @tenant_id, (@start_date.in_time_zone(@tenant.time_zone)).strftime("%Y"), (@start_date.in_time_zone(@tenant.time_zone)).strftime("%m") ).first.try(:total)
    @tenant.current_budget.budget_months.find_by(month_date: @start_date.in_time_zone(@tenant.time_zone)).total
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

  def daily_target
    # (BUDGET - ORDERS_UNTIL_YESTERDAY) / ( REMAINING_TRADING_DAYS)
    # eg. (59800 -  17057) / (23 - 10) = 3,288 (default is $2,600)
    order_total = @orders_stats.mty.sum(:grand_total)
    trading_days = @date_helper.trading_days
    trading_days_left = @date_helper.trading_days_left

    # IF
    # [TARGET <= ORDERS]
    #   OR [DAILY ORDER AVG < AVG DAILY BUDGET]
    #     OR [TRADING_DAYS_LEFT is 0]
    if target
      # SET DEFAULT = BUDGET/TRADING DAYS
      if ((target <= order_total) or ((target - order_total) / trading_days_left) <= (target / trading_days)) or (trading_days_left == 0)
        target / trading_days
      else
        (target - order_total) / trading_days_left
      end
    else
      nil
    end
  end

  def daily_target_percentage
    if daily_target
     (@orders_stats.daily_orders / daily_target) * 100
    else
      nil
    end
  end

  def goal_percentage
    target == 0 ? 0 : (sales / target) * 100
  end

  def potential_goal_percentage
    total_sales = sales + deferred.sum(:grand_total)
    target == 0 ? 0 : (total_sales / target) * 100
  end

  def last_year_current_month_sales
    10000

    # date = @start_date

    # year = date.strftime("%Y")
    # year = year.to_i - 1
    # month = date.strftime("%-m")

    # AccountingSale.where('year = (?) and month = (?) and tenant_id = (?)', year, month, @tenant_id).first.try(:total)
  end

  def last_year_goal_percentage
    (@sales.sum("grand_total") / last_year_current_month_sales) * 100
  end

  def difference_ytd_vs_ly
   (ytd.sum("grand_total").to_f - ly_ytd.sum("grand_total")) / ly_ytd.sum("grand_total") * 100
  end

  def prev_month_budgets
    financial_year = FinancialYear.new(@tenant)
    Budget.where("tenant_id = (?) and ( (fy = (?) and month < (?)) OR (year = ? AND month >= 7 ))", @tenant_id, financial_year.year(@start_date.in_time_zone(@tenant.time_zone)), @end_date.in_time_zone(@tenant.time_zone).month, financial_year.start(@start_date).year)
  end

  def current_mtd_budget
    if daily_target
    (@date_helper.trading_days_gone + 1) * daily_target
    else
      nil
    end
  end

  def budget_ytd
    prev_month_budgets.inject(0) { |memo, budget| memo += budget.total }
  end

  def budget_financial_ytd
    if current_mtd_budget
      current_mtd_budget + budget_ytd
    else
      nil
    end
  end

  def difference_ytd_vs_budget
    # difference_ytd_vs_budget = (ytd.sum('grand_total').to_f - budget_financial_ytd) / budget_financial_ytd * 100 unless budget_financial_ytd.nil?
  end

  def all
    @sales
  end

  def forecast_sales
    Sale.where(tenant: @tenant).where(pickup_date: @start_date..@end_date).where(Invoice.INVOICED + " OR " + Invoice.DEFERRED)
  end

  def deferred
    @sales = Sale.for_tenant(@tenant_id).for_dates(@start_date, @end_date)
    @sales.deferred
  end

  def deferred_history
    @sales = Sale.for_tenant(@tenant_id).for_dates(@start_date, @end_date)
    @sales.deferred
  end

  def ytd
    Sale.for_tenant(@tenant_id).for_dates(FinancialYear.start(@start_date), @end_date)
  end

  def ly_ytd
    Sale.for_tenant(@tenant_id).for_dates(FinancialYear.ly_start(@start_date), (@end_date - 1.year))
  end

  def largest
    @sales.order("grand_total DESC").first
  end

  def daily_avg
    sales / @date_helper.trading_days_gone || 0
  end

  def avg_value
    if @sales.count > 0
      avg_value = sales / @sales.count
    else
      avg_value = 0
    end
  end

  def sales
    # ::Statistic.find_or_initialize_by(
    #   tenant: @tenant,
    #   statistic_for: 'PS-MONTH',
    #   month: @start_date.month,
    #   year: @start_date.year
    # ).total || 0
    if Platform.is_printsmith?(@tenant)
      if @current
        ::Statistic.find_or_initialize_by(
          tenant: @tenant,
          statistic_for: "PS-MONTH",
          accounting_month: 0,
          accounting_year: 0
        ).total || 0
      else
        ::Statistic.find_or_initialize_by(
          tenant: @tenant,
          statistic_for: "PS-MONTH",
          accounting_month: @start_date.month,
          accounting_year: @start_date.year
        ).total || 0
      end
    elsif Platform.is_mbe?(@tenant)
     @sales.mbe_invoiced.sum(:grand_total) || 0
    end
  end

  def all_sales
    @sales = @sales
  end

  def grouped_by_date
    Chart.group_by_date(@sales, @start_date, @end_date, "pickup_date", @tenant)
  end

  def grouped_by_date_deferred
    Chart.group_by_date(deferred_history, @start_date, @end_date, "pickup_date", @tenant)
  end

  def grouped_by_date_forecast
    Chart.group_by_date(forecast_sales, @start_date, @end_date, "pickup_date", @tenant)
  end

  def cumulative_grouped_by_date
    Chart.cumulative_grouped_by_date(@sales, @start_date, @end_date, "pickup_date", @tenant)
  end

  def cumulative_grouped_by_date_deferred
    Chart.cumulative_grouped_by_date(deferred, @start_date, @end_date, "pickup_date", @tenant)
  end

  def cumulative_grouped_by_date_forecast
    Chart.cumulative_grouped_by_date(forecast_sales, @start_date, @end_date, "pickup_date", @tenant)
  end

  def total_cost
    @sales.present? ? @sales.sum(:total_cost) : 0
  end

  def grand_total_inc_tax
    @sales.present? ? @sales.sum(:grand_total_inc_tax) : 0
  end
end
