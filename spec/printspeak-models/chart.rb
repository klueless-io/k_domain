# frozen_string_literal: true

class Chart
  def self.group_by_date(collection, start_date, end_date, group_on = "ordered_date", tenant)
    collection.group_by_day(group_on.to_sym, time_zone: tenant.time_zone, range: start_date..end_date).sum(:grand_total)
  end

  def self.group_by_month(collection, start_date, end_date, group_on = "ordered_date", tenant)
    collection.group_by_month(group_on.to_sym, time_zone: tenant.time_zone, range: start_date..end_date).sum(:grand_total)
  end

  def self.cumulative_grouped_by_date(collection, start_date, end_date, group_on = "ordered_date", tenant)
    offset = Time.now.in_time_zone(tenant.time_zone).utc_offset / 3600

    _sales = collection

    # _sales = _sales.all.to_group(:sum, :day, group_on.to_sym)
    _sales = _sales.all.group("DATE_TRUNC('day', #{ group_on } AT TIME ZONE '#{offset}') ").
    order("DATE_TRUNC('day', #{ group_on } AT TIME ZONE '#{offset}')").sum(:grand_total)

    output = {}

    (start_date.to_date..end_date.to_date).inject(0) do |running_total, active_date|
      output[active_date] = running_total += _sales[active_date.beginning_of_day] || 0
    end

    output
  end
end
