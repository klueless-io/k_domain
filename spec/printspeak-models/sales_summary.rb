class SalesSummary < ActiveRecord::Base
  extend RailsUpgrade

  default_scope { where(isdeleted: false, deleted: false) }

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  # Indexes
  # CREATE INDEX CONCURRENTLY index_invoices_tenant_platform_id_voided ON invoices (tenant_id, platform_id, voided, id) WHERE (voided = FALSE OR voided IS NULL);
  # CREATE INDEX CONCURRENTLY index_account_history_data_source_invoice ON account_history_data (tenant_id, source_invoice_id, platform_id, recordType) WHERE recordType = '1';
  # CREATE INDEX CONCURRENTLY index_sales_summary_source_account_history_item ON sales_summary_pickups (tenant_id, source_account_history_item_id, source_sales_summary_id, deleted) WHERE deleted = FALSE;
  # CREATE INDEX CONCURRENTLY index_sales_summaries_tenant_platform_id_not_deleted ON sales_summaries (tenant_id, platform_id, deleted, id) WHERE deleted = FALSE;
  # CREATE INDEX CONCURRENTLY index_adjustments_affect_sales ON adjustments (affect_sales, deleted, voided, id) WHERE affect_sales = TRUE AND deleted = FALSE AND voided = FALSE;
  # CREATE INDEX CONCURRENTLY index_invoices_sales_summary_id_pickup_date ON invoices (sales_summary_id, pickup_date) WHERE sales_summary_id IS NOT NULL;
  # CREATE INDEX CONCURRENTLY index_adjustments_sales_summary_id_posted_date ON adjustments (sales_summary_id, posted_date) WHERE sales_summary_id IS NOT NULL;
  # CREATE INDEX CONCURRENTLY index_invoices_daily_sales_summary_id_totals ON invoices (daily_sales_summary_id, grand_total, rounded_amount);
  # CREATE INDEX CONCURRENTLY index_invoices_sales_summary_id_totals ON invoices (sales_summary_id, grand_total, rounded_amount);
  # CREATE INDEX CONCURRENTLY index_adjustments_daily_sales_summary_id_totals ON adjustments (daily_sales_summary_id, total);

  def is_valid?
    result = false

    if !isdeleted && !deleted
      if monthly && !accounting_year.nil?
        result = true
      end

      if daily && !daily_accounting_year.nil?
        result = true
      end
    end

    result
  end

  def perform_closeout
    return nil if !is_valid?

    now = Time.zone.now
    now_in_timezone = now.in_time_zone(tenant.time_zone)

    start_date = now
    end_date = now

    if daily
      start_date = closeoutdate.to_datetime.in_time_zone(tenant.time_zone).beginning_of_day.utc
      end_date = closeoutdate.to_datetime.in_time_zone(tenant.time_zone).end_of_day.utc
    end

    if monthly
      start_date = closeoutdate.to_datetime.in_time_zone(tenant.time_zone).beginning_of_month.utc
      end_date = closeoutdate.to_datetime.in_time_zone(tenant.time_zone).end_of_month.utc
    end

    invoices_platform_conditions = nil
    if Platform.is_printsmith?(tenant)
      invoices_platform_conditions = %Q{
        AND EXISTS (
          SELECT null
          FROM account_history_data
          WHERE account_history_data.tenant_id = #{tenant_id}
          AND account_history_data.recordType = '1'
          AND account_history_data.source_invoice_id::TEXT = invoices.platform_id
          AND EXISTS (
            SELECT null
            FROM sales_summary_pickups
            WHERE sales_summary_pickups.tenant_id = #{tenant_id}
            AND sales_summary_pickups.deleted = FALSE
            AND sales_summary_pickups.source_account_history_item_id::TEXT = account_history_data.platform_id
            AND EXISTS (
              SELECT null
              FROM sales_summaries
              WHERE sales_summaries.tenant_id = #{tenant_id}
              AND sales_summaries.deleted = FALSE
              AND sales_summaries.platform_id = sales_summary_pickups.source_sales_summary_id::TEXT
              AND sales_summaries.id = #{id}
            )
          )
        )
      }
    elsif Platform.is_mbe?(tenant)
      invoices_platform_conditions = %Q{
        AND pickup_date > #{ActiveRecord::Base::sanitize(start_date)}
        AND pickup_date <= #{ActiveRecord::Base::sanitize(end_date)}
      }
    end

    select_invoices_query = %Q{
      SELECT invoices.id
      FROM invoices
      WHERE invoices.tenant_id = #{tenant_id}
      AND (
        invoices.voided = FALSE
        OR invoices.voided IS NULL
      )
      #{invoices_platform_conditions}
      ORDER BY invoices.id ASC
    }

    adjustments_platform_conditions = nil
    if Platform.is_printsmith?(tenant)
      adjustments_platform_conditions = %Q{
        AND EXISTS (
          SELECT null
          FROM account_history_data
          WHERE account_history_data.tenant_id = #{tenant_id}
          AND account_history_data.recordType = '3'
          AND account_history_data.source_journal_id::TEXT = adjustments.platform_id
          AND EXISTS (
            SELECT null
            FROM sales_summary_pickups
            WHERE sales_summary_pickups.tenant_id = #{tenant_id}
            AND sales_summary_pickups.deleted = FALSE
            AND sales_summary_pickups.source_account_history_item_id::TEXT = account_history_data.platform_id
            AND EXISTS (
              SELECT null
              FROM sales_summaries
              WHERE sales_summaries.tenant_id = #{tenant_id}
              AND sales_summaries.deleted = FALSE
              AND sales_summaries.platform_id = sales_summary_pickups.source_sales_summary_id::TEXT
              AND sales_summaries.id = #{id}
            )
          )
        )
      }
    end

    select_adjustments_query = %Q{
      SELECT adjustments.id
      FROM adjustments
      WHERE adjustments.tenant_id = #{tenant_id}
      AND adjustments.affect_sales = TRUE
      AND adjustments.deleted = FALSE
      AND adjustments.voided = FALSE
      #{adjustments_platform_conditions}
      ORDER BY adjustments.id ASC
    }

    select_shipments_query = %Q{
      SELECT shipments.id
      FROM shipments
      WHERE shipments.tenant_id = #{tenant_id}
      AND shipments.deleted = FALSE
      AND shipments.voided = FALSE
      AND shipment_date > #{ActiveRecord::Base::sanitize(start_date)}
      AND shipment_date <= #{ActiveRecord::Base::sanitize(end_date)}
      ORDER BY shipments.id ASC
    }


    self.attempts += 1
    invoice_values = nil

    if monthly
      invoice_values = %Q{
        accounting_month = #{accounting_month},
        accounting_year = #{accounting_year},
        sales_summary_id = #{id}
      }
    end

    if daily
      invoice_values = %Q{
        daily_accounting_day = #{daily_accounting_day},
        daily_accounting_month = #{daily_accounting_month},
        daily_accounting_year = #{daily_accounting_year},
        daily_sales_summary_id = #{id}
      }
    end

    if !invoice_values.blank?
      invoice_ids_result = ActiveRecord::Base.connection.execute(select_invoices_query)

      if invoice_ids_result
        invoice_ids = invoice_ids_result.map { |i| i["id"].to_i }
        if invoice_ids.count > 0
          update_invoices_query = %Q{
            UPDATE invoices
            SET #{invoice_values}
            WHERE invoices.id IN (
              #{invoice_ids.to_csv}
            )
          }
          ActiveRecord::Base.connection.execute(update_invoices_query)

          self.invoice_count = invoice_ids.count
          save
        end
      end
    end

    adjustment_values = nil

    if monthly
      adjustment_values = %Q{
        accounting_month = #{accounting_month},
        accounting_year = #{accounting_year},
        sales_summary_id = #{id}
      }
    end

    if daily
      adjustment_values = %Q{
        daily_accounting_day = #{daily_accounting_day},
        daily_accounting_month = #{daily_accounting_month},
        daily_accounting_year = #{daily_accounting_year},
        daily_sales_summary_id = #{id}
      }
    end

    if !adjustment_values.blank? && Platform.is_printsmith?(tenant)
      adjustment_ids_result = ActiveRecord::Base.connection.execute(select_adjustments_query)

      if adjustment_ids_result
        adjustment_ids = adjustment_ids_result.map { |i| i["id"].to_i }
        if adjustment_ids.count > 0
          update_adjustments_query = %Q{
            UPDATE adjustments
            SET #{adjustment_values}
            WHERE adjustments.id IN (
              #{adjustment_ids.to_csv}
            )
          }

          ActiveRecord::Base.connection.execute(update_adjustments_query)
        end
      end
    end

    shipment_values = nil

    if monthly
      shipment_values = %Q{
        accounting_month = #{accounting_month},
        accounting_year = #{accounting_year},
        sales_summary_id = #{id}
      }
    end

    if daily
      shipment_values = %Q{
        daily_accounting_day = #{daily_accounting_day},
        daily_accounting_month = #{daily_accounting_month},
        daily_accounting_year = #{daily_accounting_year},
        daily_sales_summary_id = #{id}
      }
    end

    if !shipment_values.blank?
      shipment_ids_result = ActiveRecord::Base.connection.execute(select_shipments_query)

      if shipment_ids_result
        shipment_ids = shipment_ids_result.map { |i| i["id"].to_i }
        if shipment_ids.count > 0
          update_shipments_query = %Q{
            UPDATE shipments
            SET #{shipment_values}
            WHERE shipments.id IN (
              #{shipment_ids.to_csv}
            )
          }
          ActiveRecord::Base.connection.execute(update_shipments_query)
        end
      end
    end


    if daily
      daily_sales_stats = generate_sales_stats
      daily_sales = daily_sales_stats.try(:[], :total) || 0
      difference = balanced_sales - daily_sales
      self.difference = difference
      if difference.abs <= 100
        self.complete = true
        self.accurate = true
      else
        self.complete = false
        if self.attempts <= 10
          Event.queue(tenant, "sales_summary_perform_closeout", data: {sales_summary_id: id}, schedule_date: Time.now + (5.minutes * (self.attempts * self.attempts)), unique_for: ["scheduled"])
        end
      end
      save
    end

    if monthly
      monthly_sales_stats = generate_sales_stats
      monthly_sales = 0
      monthly_sales = monthly_sales_stats.try(:[], :total) || 0
      difference = balanced_sales - monthly_sales
      self.difference = difference
      if difference.abs <= 100
        self.complete = true
        self.accurate = true
      else
        self.complete = false
        if self.attempts <= 10
          Event.queue(tenant, "sales_summary_perform_closeout", data: {sales_summary_id: id}, schedule_date: Time.now + (5.minutes * (self.attempts * self.attempts)), unique_for: ["scheduled"])
        end
      end
      save
    end

    nil
  end

  def generate_sales_stats
    result = nil
    now = Time.zone.now
    now_in_timezone = now.in_time_zone(tenant.time_zone)

    if daily
      start_date = closeoutdate.to_datetime.in_time_zone(tenant.time_zone).beginning_of_day.utc
      end_date = closeoutdate.to_datetime.in_time_zone(tenant.time_zone).end_of_day.utc

      daily_invoices_query = %Q{
        SELECT ROUND(COALESCE(SUM(invoices.grand_total), 0), 2) AS invoice_sales, ROUND(COALESCE(SUM(invoices.rounded_amount), 0), 2) AS markups
        FROM invoices
        WHERE invoices.daily_sales_summary_id = #{id}
      }
      daily_invoices = ActiveRecord::Base.connection.execute(daily_invoices_query).first

      daily_adjustments_query = %Q{
        SELECT ROUND(COALESCE(SUM(adjustments.total), 0), 2) AS total, ROUND(COALESCE(SUM(adjustments.markups), 0), 2) AS markups
        FROM adjustments
        WHERE adjustments.daily_sales_summary_id = #{id}
      }
      daily_adjustments = ActiveRecord::Base.connection.execute(daily_adjustments_query).first

      daily_sales_base_taxes_query = %Q{
        SELECT ROUND(COALESCE(SUM(CASE WHEN sales_base_taxes.source_type IN (7, 8) THEN (sales_base_taxes.total_taxable + sales_base_taxes.total_non_taxable) ELSE 0 END), 0), 2) AS cash_sales, ROUND(COALESCE(SUM(CASE WHEN sales_base_taxes.source_type = 12 THEN (sales_base_taxes.total_taxable + sales_base_taxes.total_non_taxable) ELSE 0 END), 0), 2) AS finance_charges
        FROM sales_base_taxes
        INNER JOIN sales_summaries ON sales_summaries.platform_id = sales_base_taxes.source_sales_base_id::TEXT
        WHERE sales_base_taxes.tenant_id = #{tenant_id}
        AND sales_summaries.isdeleted = FALSE
        AND sales_base_taxes.source_type IN (7, 8, 12)
        AND sales_summaries.daily = TRUE
        AND sales_base_taxes.posted_date >= '#{start_date}'::timestamp
        AND sales_base_taxes.posted_date < ('#{start_date}'::timestamp + interval '1 day')::timestamp
      }
      daily_sales_base_taxes = ActiveRecord::Base.connection.execute(daily_sales_base_taxes_query).first

      total_finance_charges = 0.0
      total_finance_charges = daily_sales_base_taxes["finance_charges"].to_f if !tenant.exclude_non_sales

      result = {
        invoice_sales: daily_invoices["invoice_sales"].to_f,
        adjustments: daily_adjustments["total"].to_f - daily_adjustments["markups"].to_f,
        markups: daily_invoices["markups"].to_f + daily_adjustments["markups"].to_f,
        cash_sales: daily_sales_base_taxes["cash_sales"].to_f,
        finance_charges: daily_sales_base_taxes["finance_charges"].to_f,
        total: daily_invoices["invoice_sales"].to_f + daily_adjustments["total"].to_f + daily_invoices["markups"].to_f + daily_sales_base_taxes["cash_sales"].to_f + total_finance_charges
      }
    end

    if monthly
      first_date = nil
      last_date = nil
      last_closeout = nil
      invoices_accounting_date_condition = ""
      adjustments_accounting_date_condition = ""
      sales_base_tax_accounting_date_condition = ""

      if accounting_year == 0
        invoices_accounting_date_condition = %Q{
          AND invoices.accounting_month IS NULL
          AND invoices.accounting_year IS NULL
        }
        adjustments_accounting_date_condition = %Q{
          AND adjustments.accounting_month IS NULL
          AND adjustments.accounting_year IS NULL
        }
        sales_base_tax_accounting_date_condition = %Q{
          AND sales_summaries.daily = TRUE
        }

        last_closeout = SalesSummary.most_recent_monthly_closeout(tenant).try(:closeoutdate).try(:to_datetime)

        if last_closeout && now_in_timezone.year == last_closeout.in_time_zone(tenant.time_zone).year && now_in_timezone.month == last_closeout.in_time_zone(tenant.time_zone).month
          second_to_last_closeout = SalesSummary.second_most_recent_monthly_closeout(tenant).try(:closeoutdate).try(:to_datetime)
          invoices_accounting_date_condition = %Q{
            AND (
              (
                invoices.accounting_month IS NULL
                AND invoices.accounting_year IS NULL
              )
              OR
              (
                invoices.accounting_month = #{now_in_timezone.month}
                AND invoices.accounting_year = #{now_in_timezone.year}
              )
            )
          }
          adjustments_accounting_date_condition = %Q{
            AND (
              (
                adjustments.accounting_month IS NULL
                AND adjustments.accounting_year IS NULL
              )
              OR
              (
                adjustments.accounting_month = #{now_in_timezone.month}
                AND adjustments.accounting_year = #{now_in_timezone.year}
              )
            )
          }
        end

        if second_to_last_closeout
          first_date = second_to_last_closeout
        else
          first_date = now_in_timezone.beginning_of_month.utc
        end
        last_date = now_in_timezone.beginning_of_day.utc + 1.day
      else
        invoices_accounting_date_condition = %Q{
          AND invoices.accounting_month = #{accounting_month}
          AND invoices.accounting_year = #{accounting_year}
        }
        adjustments_accounting_date_condition = %Q{
          AND adjustments.accounting_month = #{accounting_month}
          AND adjustments.accounting_year = #{accounting_year}
        }
        shipments_accounting_date_condition = %Q{
          AND shipments.accounting_month = #{accounting_month}
          AND shipments.accounting_year = #{accounting_year}
        }
        sales_base_tax_accounting_date_condition = %Q{
          AND sales_summaries.monthly = TRUE
          AND sales_base_taxes.source_sales_base_id = #{platform_id.blank? ? 0 : platform_id}
        }

        invoice_dates_query = %Q{
          SELECT MIN(invoices.pickup_date) AS first_date, MAX(invoices.pickup_date) AS last_date
          FROM invoices
          WHERE invoices.sales_summary_id = #{id}
        }
        invoice_dates = ActiveRecord::Base.connection.execute(invoice_dates_query).first
        if !invoice_dates["first_date"].blank?
          first_date = invoice_dates["first_date"].to_datetime
        end
        if !invoice_dates["last_date"].blank?
          last_date = invoice_dates["last_date"].to_datetime
        end

        adjustment_dates_query = %Q{
          SELECT MIN(adjustments.posted_date) AS first_date, MAX(adjustments.posted_date) AS last_date
          FROM adjustments
          WHERE adjustments.sales_summary_id = #{id}
        }
        adjustment_dates = ActiveRecord::Base.connection.execute(adjustment_dates_query).first
        if !adjustment_dates["first_date"].blank? && (first_date.blank? || (!first_date.blank? && adjustment_dates["first_date"].to_datetime < first_date))
          first_date = adjustment_dates["first_date"].to_datetime
        end
        if !adjustment_dates["last_date"].blank? && (last_date.blank? || (!last_date.blank? && adjustment_dates["last_date"].to_datetime > last_date))
          last_date = adjustment_dates["last_date"].to_datetime
        end

        if first_date.blank?
          first_date = closeoutdate.to_datetime
        end

        if last_date.blank?
          last_date = closeoutdate.to_datetime
        end
      end

      first_date = first_date.in_time_zone(tenant.time_zone).beginning_of_day.utc
      last_date = last_date.in_time_zone(tenant.time_zone).end_of_day.utc

      daily_stats_query = %Q{
        SELECT sales_for_date.date AS date,
               sales.total AS invoice_sales,
               sales.invoiced_sales AS invoiced_sales,
               sales.deferred_sales AS deferred_sales,
               shipments.total AS shipments_total,
               orders.total AS order_intake,
               sales.markups AS markups,
               adjustments.total AS adjustments_total,
               adjustments.markups AS adjustment_markups,
               outside_adjustments.total AS outside_adjustments_total,
               outside_adjustments.markups AS outside_adjustment_markups,
               base_taxes.cash_sales AS cash_sales,
               base_taxes.finance_charges AS finance_charges
        FROM (
          SELECT sales_for_date AS date
          FROM GENERATE_SERIES(timestamp '#{first_date}', '#{last_date}', interval '1 day') sales_for_date
        ) sales_for_date
        LEFT JOIN LATERAL (
          SELECT ROUND(COALESCE(SUM(invoices.grand_total), 0), 2) AS total,
                 ROUND(COALESCE(SUM(invoices.rounded_amount), 0), 2) AS markups,
                 ROUND(COALESCE(SUM(CASE WHEN #{Invoice.INVOICED} THEN COALESCE(invoices.grand_total, 0) ELSE 0 END), 0), 2) AS invoiced_sales,
                 ROUND(COALESCE(SUM(CASE WHEN #{Invoice.DEFERRED} THEN COALESCE(invoices.grand_total, 0) ELSE 0 END), 0), 2) AS deferred_sales
          FROM invoices
          WHERE invoices.tenant_id = #{tenant_id}
          AND invoices.voided = FALSE
          AND invoices.deleted = FALSE
          #{invoices_accounting_date_condition}
          AND invoices.pickup_date >= sales_for_date.date::timestamp
          AND invoices.pickup_date < (sales_for_date.date + interval '1 day')::timestamp
        ) sales ON TRUE
        LEFT JOIN LATERAL (
          SELECT ROUND(COALESCE(SUM(shipments.grand_total), 0), 2) AS total
          FROM shipments
          WHERE shipments.tenant_id = #{tenant_id}
          AND shipments.voided = FALSE
          AND shipments.deleted = FALSE
          #{shipments_accounting_date_condition}
          AND shipments.shipment_date >= sales_for_date.date::timestamp
          AND shipments.shipment_date < (sales_for_date.date + interval '1 day')::timestamp
        ) shipments ON TRUE
        LEFT JOIN LATERAL (
          SELECT ROUND(COALESCE(SUM(invoices.grand_total), 0), 2) AS total
          FROM invoices
          WHERE invoices.tenant_id = #{tenant_id}
          AND invoices.voided = FALSE
          AND invoices.deleted = FALSE
          AND invoices.ordered_date >= sales_for_date.date::timestamp
          AND invoices.ordered_date < (sales_for_date.date + interval '1 day')::timestamp
        ) orders ON TRUE
        LEFT JOIN LATERAL (
          SELECT ROUND(COALESCE(SUM(adjustments.total), 0), 2) AS total,
                 ROUND(COALESCE(SUM(adjustments.markups), 0), 2) AS markups
          FROM adjustments
          WHERE adjustments.tenant_id = #{tenant_id}
          AND adjustments.voided = FALSE
          AND adjustments.deleted = FALSE
          AND adjustments.affect_sales = TRUE
          #{adjustments_accounting_date_condition}
          AND adjustments.posted_date >= sales_for_date.date::timestamp
          AND adjustments.posted_date < (sales_for_date.date + interval '1 day')::timestamp
        ) adjustments ON TRUE
        LEFT JOIN LATERAL (
          SELECT ROUND(COALESCE(SUM(adjustments.total), 0), 2) AS total,
                 ROUND(COALESCE(SUM(adjustments.markups), 0), 2) AS markups
          FROM adjustments
          WHERE adjustments.tenant_id = #{tenant_id}
          AND adjustments.voided = FALSE
          AND adjustments.deleted = FALSE
          AND adjustments.affect_sales = TRUE
          #{adjustments_accounting_date_condition}
          AND adjustments.posted_date >= '#{last_date}'
          AND adjustments.posted_date < '#{first_date}'
          AND sales_for_date.date = '#{first_date}'
        ) outside_adjustments ON TRUE
        LEFT JOIN LATERAL (
          SELECT ROUND(COALESCE(SUM(CASE WHEN sales_base_taxes.source_type IN (7, 8) THEN (sales_base_taxes.total_taxable + sales_base_taxes.total_non_taxable) ELSE 0 END), 0), 2) AS cash_sales,
                 ROUND(COALESCE(SUM(CASE WHEN sales_base_taxes.source_type = 12 THEN (sales_base_taxes.total_taxable + sales_base_taxes.total_non_taxable) ELSE 0 END), 0), 2) AS finance_charges
          FROM sales_base_taxes
          INNER JOIN sales_summaries ON sales_summaries.platform_id = sales_base_taxes.source_sales_base_id::TEXT
          WHERE sales_base_taxes.tenant_id = #{tenant_id}
          AND sales_summaries.isdeleted = FALSE
          #{sales_base_tax_accounting_date_condition}
          AND sales_base_taxes.source_type IN (7, 8, 12)
          AND sales_base_taxes.posted_date >= sales_for_date.date::timestamp
          AND sales_base_taxes.posted_date < (sales_for_date.date + interval '1 day')::timestamp
        ) base_taxes ON TRUE
      }

      monthly_stats = {
        invoice_sales: 0,
        adjustments: 0,
        markups: 0,
        cash_sales: 0,
        finance_charges: 0,
        total: 0,
        order_intake: 0,
        invoiced_sales: 0,
        deferred_sales: 0,
        shipments: 0
      }
      daily_stat_ids = []
      daily_stats = ActiveRecord::Base.connection.execute(daily_stats_query)
      daily_stats.each do |daily_stat|
        date_in_time_zone = daily_stat["date"].to_datetime.in_time_zone(tenant.time_zone)
        sales_stat = Statistic.find_or_initialize_by(
          tenant: tenant,
          statistic_for: "PS-DAY",
          date: date_in_time_zone.to_date,
          accounting_month: accounting_month,
          accounting_year: accounting_year
        )
        sales_stat.invoice_sales = daily_stat["invoice_sales"].to_f
        sales_stat.invoiced_sales = daily_stat["invoiced_sales"].to_f
        sales_stat.deferred_sales = daily_stat["deferred_sales"].to_f
        sales_stat.shipments = daily_stat["shipments_total"].to_f
        sales_stat.order_intake = daily_stat["order_intake"].to_f
        sales_stat.adjustments = (daily_stat["adjustments_total"].to_f - daily_stat["adjustment_markups"].to_f) + (daily_stat["outside_adjustments_total"].to_f - daily_stat["outside_adjustment_markups"].to_f)
        sales_stat.markups = daily_stat["markups"].to_f + daily_stat["adjustment_markups"].to_f + daily_stat["outside_adjustment_markups"].to_f
        sales_stat.cash_sales = daily_stat["cash_sales"].to_f
        sales_stat.finance_charges = daily_stat["finance_charges"].to_f

        if accounting_year == 0 && date_in_time_zone.to_date == now_in_timezone.to_date
          begin
            sales_stat.cash_sales += CashSale.current_non_closed_out_cash_sales(tenant, first_date.in_time_zone(tenant.time_zone), last_date.in_time_zone(tenant.time_zone))
            sales_stat.finance_charges += FinanceCharge.current_non_closed_out_finance_charges(tenant, first_date.in_time_zone(tenant.time_zone), last_date.in_time_zone(tenant.time_zone))
          rescue StandardError
          end
        end

        if Platform.is_printsmith?(tenant)
          sales_stat.total = sales_stat.invoice_sales + sales_stat.adjustments + sales_stat.markups + sales_stat.cash_sales
          sales_stat.total += sales_stat.finance_charges if !tenant.exclude_non_sales
        elsif Platform.is_mbe?(tenant)
          sales_stat.total = sales_stat.invoiced_sales + sales_stat.adjustments
        end
        sales_stat.save
        daily_stat_ids << sales_stat.id
        monthly_stats[:invoice_sales] += sales_stat.invoice_sales
        monthly_stats[:invoiced_sales] += sales_stat.invoiced_sales
        monthly_stats[:deferred_sales] += sales_stat.deferred_sales
        monthly_stats[:shipments] += sales_stat.shipments
        monthly_stats[:order_intake] += sales_stat.order_intake
        monthly_stats[:adjustments] += sales_stat.adjustments
        monthly_stats[:markups] += sales_stat.markups
        monthly_stats[:cash_sales] += sales_stat.cash_sales
        monthly_stats[:finance_charges] += sales_stat.finance_charges
        monthly_stats[:total] += sales_stat.total
      end

      if accounting_year == 0
        old_stat_ids = Statistic.where(tenant: tenant, statistic_for: "PS-DAY", accounting_month: 0, accounting_year: 0).where.not(id: daily_stat_ids).pluck(:id)
        if old_stat_ids.count > 0
          Statistic.where(id: old_stat_ids).delete_all
        end
      end

      monthly_sales_stat = Statistic.find_or_initialize_by(
        tenant: tenant,
        statistic_for: "PS-MONTH",
        accounting_year: accounting_year,
        accounting_month: accounting_month
      )

      monthly_sales_stat.invoice_sales = monthly_stats[:invoice_sales]
      monthly_sales_stat.invoiced_sales = monthly_stats[:invoiced_sales]
      monthly_sales_stat.deferred_sales = monthly_stats[:deferred_sales]
      monthly_sales_stat.shipments = monthly_stats[:shipments]
      monthly_sales_stat.adjustments = monthly_stats[:adjustments]
      monthly_sales_stat.markups = monthly_stats[:markups]
      monthly_sales_stat.cash_sales = monthly_stats[:cash_sales]
      monthly_sales_stat.finance_charges = monthly_stats[:finance_charges]
      monthly_sales_stat.total = monthly_stats[:total]
      monthly_sales_stat.order_intake = monthly_stats[:order_intake]
      if accounting_year == 0
        if last_closeout && now_in_timezone.year == last_closeout.in_time_zone(tenant.time_zone).year && now_in_timezone.month == last_closeout.in_time_zone(tenant.time_zone).month
          monthly_sales_stat.date = now_in_timezone.end_of_month.to_date + 1
        else
          monthly_sales_stat.date = now_in_timezone.beginning_of_month.to_date
        end
      else
        monthly_sales_stat.date = Date.strptime("1-#{accounting_month}-#{accounting_year}", "%d-%m-%Y")
      end
      monthly_sales_stat.save

      result = monthly_stats
    end

    result
  end

  def balanced_sales
    result = (nontaxsales || 0) + (taxablesales || 0)
    if tenant.exclude_non_sales
      result = totalsales || 0
    end
    result
  end

  def self.generate_current_month_stats(target_tenant)
    sales_summary = SalesSummary.new(
      tenant_id: target_tenant.id,
      monthly: true,
      platform_id: 0,
      accounting_month: 0,
      accounting_year: 0
    )
    sales_summary.generate_sales_stats
  end

  def self.monthly_closeouts(tenant)
    where(tenant: tenant).
      where(monthly: true).
      order(closeoutdate: :desc)
  end
  private_class_method :monthly_closeouts

  def self.most_recent_monthly_closeout(tenant)
    monthly_closeouts(tenant).limit(1).first
  end

  def self.second_most_recent_monthly_closeout(tenant)
    monthly_closeouts(tenant).offset(1).limit(1).first
  end

  def sales
    if tenant.exclude_non_sales
      totalsales.to_f
    else
      (nontaxsales + taxablesales).to_f
    end
  end
end
