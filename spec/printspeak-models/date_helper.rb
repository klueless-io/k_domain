class DateHelper
  def initialize(start_date, end_date, tenant)
    @start_date   = start_date
    @end_date     = end_date
    @tenant       = tenant
  end

  def active_date_range
    (@start_date.in_time_zone(@tenant.time_zone).to_date..@end_date.in_time_zone(@tenant.time_zone).to_date)
  end

  def current_month_date_range
    (@start_date.in_time_zone(@tenant.time_zone).to_date..@end_date.in_time_zone(@tenant.time_zone).to_date.end_of_month)
  end

  # attr_reader :current_user, :session
  def trading_days
    # COUNT UNIQUE HOLIDAY DATES (current month)
    holiday_dates_count = uniq_holidays_dates_in_working_days(holidays)

     # RETURN TRADING DAYS (current month) - holiday_dates_count
    business_days_between((@start_date.in_time_zone(@tenant.time_zone).beginning_of_month), (@end_date.in_time_zone(@tenant.time_zone).end_of_month)) - holiday_dates_count
  end

    # attr_reader :current_user, :session
  def trading_days_range
    # COUNT UNIQUE HOLIDAY DATES (current month)
    holiday_dates_count = uniq_holidays_dates_in_working_days(holidays(@start_date, @end_date))

    # RETURN TRADING DAYS (current month) - holiday_dates_count
    business_days_between(@start_date.in_time_zone(@tenant.time_zone), @end_date.in_time_zone(@tenant.time_zone)) - holiday_dates_count
  end

  def trading_days_gone
    # COUNT UNIQUE HOLIDAY DATES UNTIL @end_date
    holiday_dates_count = uniq_holidays_dates_in_working_days(holidays.gone(@end_date))

    # RETURN TRADING DAYS GONE (UNTIL YESTERDAY) - holiday_dates_count
    res = business_days_between(
      @start_date.in_time_zone(@tenant.time_zone).beginning_of_month,
      @end_date.in_time_zone(@tenant.time_zone) - 1.day
    ) - holiday_dates_count

    if res > trading_days
      trading_days
    else
      res
    end
  end

  def trading_days_gone_with_current
    # SET CURRENT DAY IF NO TRADING DAYS GONE
    if trading_days_gone.nil?
      1
    else
      trading_days_gone + 1
    end
  end

  def trading_days_left
    # COUNT UNIQUE HOLIDAY DATES (from today till end of month)
    holiday_dates_count = uniq_holidays_dates_in_working_days(holidays.left(@end_date))

    # RETURN TRADING DAYS (@end_Date -> to end of month) - holiday_dates_count
    business_days_remaining = business_days_between(@end_date.in_time_zone(@tenant.time_zone), @end_date.in_time_zone(@tenant.time_zone).end_of_month)
    business_days_remaining - holiday_dates_count unless trading_days.nil?
  end

  # COUNT - TRADING DAYS GONE + CURRENT DAY
  def trading_days_gone_percentage
    (trading_days_gone_with_current.to_f / trading_days) * 100 unless trading_days_gone.nil? or trading_days.nil?
  end

  def saturdays
    active_date_range.find_all { |day| day.wday == 6 } # 6 == Saturday
  end

  def weekends
    saturdays.map do |saturday|
      # given this "saturday"  what's the index in @active_date_range for that date
      { color: "#f6f6f6",
        from: active_date_range.to_a.index(saturday),
        to: active_date_range.to_a.index(saturday) + 1 }
    end.to_json
  end

  def business_days_between(date1, date2)
    business_days = 0

    while date1 <= date2
      business_days = business_days + 1 unless date1.saturday? or date1.sunday?
      date1 = date1 + 1.day
    end
    business_days
  end

  def holidays(start_date = nil, end_date = nil)
    if (start_date.present? and end_date.present?)
      Holiday.tenant(@tenant).where('holiday_dates.date': start_date..end_date)
    else
      Holiday.tenant(@tenant).by_month_year(@start_date.month, @start_date.year)
    end
  end

  def uniq_holidays_dates_in_working_days(holidays)
    holiday_dates_array = []
    holidays.map {
      |holiday| holiday.holiday_dates.select {
        |holiday_date| holiday_dates_array << holiday_date.date unless holiday_date.date.saturday? or holiday_date.date.sunday?
      }
    }
    holiday_dates_array.uniq.count
  end

  def month_name(id, short = 0)
    array = [
      %w[January February March April May June July August September October November December],
      %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec],
    ]
    array[short][id]
  end

  def get_date_offset(date)
    Date.strptime(date, @tenant.date_format(true)).in_time_zone(@tenant.time_zone).formatted_offset
  end
end
