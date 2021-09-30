# frozen_string_literal: true

class FinancialYear
  def initialize(tenant)
    @tenant = tenant
  end

  def start_date(current_date = Time.now)
    current_date = current_date.in_time_zone(@tenant.time_zone)
    year = current_date.year
    if current_date.month < @tenant.financial_year_start_month || (current_date.month == @tenant.financial_year_start_month && current_date.day < @tenant.financial_year_start_day)
      year -= 1
    end

    DateTime.new(year, @tenant.financial_year_start_month, @tenant.financial_year_start_day, 0, 0, 0, current_date.formatted_offset)
  end

  def end_date(current_date = Time.now)
    current_date = current_date.in_time_zone(@tenant.time_zone)
    year = (start_date(current_date) + 1.year).year
    DateTime.new(year, @tenant.financial_year_start_month, @tenant.financial_year_start_day, 0, 0, 0, current_date.formatted_offset) - 1.second
  end

  def year(current_date = Time.now)
    end_date(current_date).year
  end

  alias start start_date
  alias end end_date

  def label
    "FY#{year}"
  end

  def ly_start(current_date = Time.now)
    start_date(current_date - 1.year)
  end

  def ly_end(current_date = Time.now)
    end_date(current_date - 1.year)
  end

  def current
    new(Time.now)
  end
end
