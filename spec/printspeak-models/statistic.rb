class Statistic < ActiveRecord::Base
  belongs_to :company
  belongs_to :user
  belongs_to :location
  belongs_to :tenant

  scope :current_accounting_month, -> { where(accounting_year: 0, accounting_month: 0) }

  def needs_save?
    if !total.nil? || !average.nil? || !count.nil?
      true
    else
      false
    end
  end

  def self.generate_statistic_for_day(statistic_for, tenant, target_datetime, &block)
    needs_recalc = Time.now.in_time_zone(tenant.time_zone) <= target_datetime.end_of_day

    tenant_stat = ::Statistic.find_or_initialize_by(
      tenant: tenant,
      statistic_for: "tenant-#{statistic_for}",
      date: target_datetime.to_date
    )
    block.call("tenant", tenant, tenant_stat)
    tenant_stat.needs_recalc = needs_recalc
    tenant_stat.save if tenant_stat.needs_save?

    users = tenant.users.where(hide: false)
    users.each do |user|
      taken_by_stat = ::Statistic.find_or_initialize_by(
        tenant: tenant,
        user: user,
        statistic_for: statistic_for,
        date: target_datetime.to_date
      )
      block.call("user", user, taken_by_stat)
      taken_by_stat.needs_recalc = needs_recalc
      taken_by_stat.save if taken_by_stat.needs_save?

      unless tenant.sales_rep_for_locations
        sales_rep_stat = ::Statistic.find_or_initialize_by(
          tenant: tenant,
          sales_rep_user_id: user.id,
          statistic_for: statistic_for,
          date: target_datetime.to_date
        )
        block.call("sales_rep", user, sales_rep_stat)
        sales_rep_stat.needs_recalc = needs_recalc
        sales_rep_stat.save if sales_rep_stat.needs_save?
      end
    end

    if tenant.sales_rep_for_locations
      locations = tenant.locations

      locations.each do |location|
        location_stat = ::Statistic.find_or_initialize_by(
          tenant: tenant,
          location: location,
          statistic_for: statistic_for,
          date: target_datetime.to_date
        )
        block.call("location", location, location_stat)
        location_stat.needs_recalc = needs_recalc
        location_stat.save if location_stat.needs_save?
      end
    end

    needs_recalc
  end

  def self.get_statistic_for_tenant_for_month(statistic_for, tenant, target_datetime)
    stats = ::Statistic.where(statistic_for: statistic_for, date: target_datetime.beginning_of_month..target_datetime.end_of_month).where.not(user_id: nil)
    stats = stats.where(tenant: tenant) unless tenant.nil?
    stat_totals = stats.select("sum(total) as tenant_total, avg(average) as tenant_avg, sum(count) as tenant_count").to_a.first
    {stat_total: stat_totals.tenant_total, stat_avg: stat_totals.tenant_avg, stat_count: stat_totals.tenant_count}
  end
end
