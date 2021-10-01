class CashSale
  def self.all_for_daily(tenant, daily_accounting_year, daily_accounting_month, daily_accounting_day)
    sales_summary = SalesSummary.where(tenant: tenant).
                                 where(daily: true, deleted: false).
                                 where(daily_accounting_year: daily_accounting_year).
                                 where(daily_accounting_month: daily_accounting_month).
                                 where(daily_accounting_day: daily_accounting_day).first
    if sales_summary
      cash_sales = SalesBaseTax.select("SUM(total_taxable + total_non_taxable) AS cash_sales").where(tenant: tenant).where(source_type: [7, 8], source_sales_base_id: sales_summary.platform_id).reorder("").try(:first).try(:cash_sales)
      # cash_sales = SalesBaseTax.where(tenant: tenant).where(source_type: 7, source_sales_base_id: sales_summary.platform_id).
      #           sum(:total_taxable) +
      #           SalesBaseTax.where(tenant: tenant).where(source_type: 7, source_sales_base_id: sales_summary.platform_id).
      #           sum(:total_non_taxable) + SalesBaseTax.where(tenant: tenant).where(source_type: 8, source_sales_base_id: sales_summary.platform_id).
      #           sum(:total_non_taxable) + SalesBaseTax.where(tenant: tenant).where(source_type: 8, source_sales_base_id: sales_summary.platform_id).
      #           sum(:total_taxable)

      cash_sales = 0 if !cash_sales
    else
      cash_sales = 0
    end

    cash_sales
  end

  def self.all_department_cash(tenant, accounting_year, accounting_month)
    sales_summary = SalesSummary.where(tenant: tenant).
                                 where(monthly: true, deleted: false).
                                 where(accounting_year: accounting_year).
                                 where(accounting_month: accounting_month).first
    if sales_summary
      cash_sales = SalesBaseTax.select("SUM(total_taxable + total_non_taxable) AS cash_sales").where(tenant: tenant).where(source_type: 8, source_sales_base_id: sales_summary.platform_id).reorder("").try(:first).try(:cash_sales)
      # cash_sales = SalesBaseTax.where(tenant: tenant).where(source_type: 8, source_sales_base_id: sales_summary.platform_id).
      #           sum(:total_taxable) +
      #           SalesBaseTax.where(tenant: tenant).where(source_type: 8, source_sales_base_id: sales_summary.platform_id).
      #           sum(:total_non_taxable)

      cash_sales = 0 if !cash_sales

    else
      cash_sales = 0
    end

    cash_sales
  end

  def self.closed_out_cash_sales(tenant, sales_summary)
    if sales_summary
      cash_sales = SalesBaseTax.where(tenant: tenant).where(source_type: 7, source_sales_base_id: sales_summary.platform_id)
    end

    cash_sales
  end

  def self.current_non_closed_out_cash_sales(tenant, start_date, end_date)
    sql = <<-EOF
      SELECT
        sum(totalnontaxable + totaltaxable)
        FROM tapebatch "a" INNER JOIN tapebatch_sessionbatches b ON "a"."id" = b.tapebatch_id
         INNER JOIN tapesessionbatch "c" ON b.sessionbatches_id = "c"."id"
         INNER JOIN tapesessionbatch_transactions d ON d.tapesessionbatch_id = "c"."id"
         INNER JOIN "transaction" e ON d.transactions_id = e."id"
         INNER JOIN tapesalerecord f ON e."id" = f."id"
         INNER JOIN "public".modelbase ON "public".modelbase."id" = f."id"
         INNER JOIN taxaccumtotal "t" ON e.totaltax_id = "t"."id"
        WHERE invoiceid = 0 and (e.isvoided = false or e.isvoided is null) and closed = false
         and created >= '#{start_date.strftime('%Y-%m-%d %H:%M:%S')}' and created <= '#{end_date.strftime('%Y-%m-%d %H:%M:%S')}'
    EOF

    # and closed = false
    results = tenant.connection.exec(sql)

    if results.count > 0
      total = results.sum["sum"].to_f
    else
      total = 0
    end

    total
  end
end
