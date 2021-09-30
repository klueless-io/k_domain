class FinanceCharge
  def self.all(tenant, accounting_year, accounting_month)
    sql =
    <<-EOF
      SELECT DISTINCT
      	SUM (account_history_data.total)
      FROM
      	"public"."sales_summaries" sales_summaries
      INNER JOIN "public"."sales_summary_pickups" sales_summary_pickups ON sales_summaries."platform_id" = sales_summary_pickups.source_sales_summary_id
      LEFT OUTER JOIN "public"."account_history_data" account_history_data ON sales_summary_pickups."source_account_history_item_id" = account_history_data."platform_id"
      LEFT OUTER JOIN "public"."companies" companies ON account_history_data."source_account_id" = companies."platform_id"
      LEFT OUTER JOIN "public"."adjustments" adjustments ON account_history_data.source_journal_id::TEXT = adjustments."platform_id"
      WHERE
      	sales_summaries.accounting_month = #{accounting_month}
      AND sales_summaries.accounting_year = #{accounting_year}
      AND sales_summaries.monthly = TRUE
      AND sales_summaries.tenant_id = #{tenant.id}
      AND companies.tenant_id = #{tenant.id}
      AND account_history_data.tenant_id = #{tenant.id}
      AND account_history_data."deleted" = FALSE
      AND sales_summaries."deleted" = FALSE
      AND (
      	account_history_data."recordtype" = '5'
      )
    EOF

    finance = ActiveRecord::Base.connection.execute(sql)
    finance = finance.first["sum"].to_f
  end

#   def self.all_current
#     SELECT
# *
#       FROM tapebatch "a" INNER JOIN tapebatch_sessionbatches b ON "a"."id" = b.tapebatch_id
#        INNER JOIN tapesessionbatch "c" ON b.sessionbatches_id = "c"."id"
#        INNER JOIN tapesessionbatch_transactions d ON d.tapesessionbatch_id = "c"."id"
#        INNER JOIN "transaction" e ON d.transactions_id = e."id"
#        INNER JOIN tapefinancerecord f ON e."id" = f."id"
#        INNER JOIN "public".modelbase ON "public".modelbase."id" = f."id"
#        INNER JOIN taxaccumtotal "t" ON e.totaltax_id = "t"."id"
# 	    WHERE  (e.isvoided = false or e.isvoided is null)
#
# limit 10
#
#   end

  def self.all_for_daily(tenant, daily_accounting_year, daily_accounting_month, daily_accounting_day)
    sales_summary = SalesSummary.where(tenant: tenant).
                                 where(daily: true, deleted: false).
                                 where(daily_accounting_year: daily_accounting_year).
                                 where(daily_accounting_month: daily_accounting_month).
                                 where(daily_accounting_day: daily_accounting_day).first
    if sales_summary
      finance_charge = SalesBaseTax.where(tenant: tenant).where(source_type: 12, source_sales_base_id: sales_summary.platform_id).
                sum(:total_taxable) +
                SalesBaseTax.where(tenant: tenant).where(source_type: 12, source_sales_base_id: sales_summary.platform_id).
                sum(:total_non_taxable)

      finance_charge = 0 if !finance_charge
    else
      finance_charge = 0
    end

    finance_charge
  end

  def self.current_non_closed_out_finance_charges(tenant, start_date, end_date)
    sql = <<-EOF
      SELECT
        sum(totalnontaxable + totaltaxable)
      FROM tapebatch "a" INNER JOIN tapebatch_sessionbatches b ON "a"."id" = b.tapebatch_id
       INNER JOIN tapesessionbatch "c" ON b.sessionbatches_id = "c"."id"
       INNER JOIN tapesessionbatch_transactions d ON d.tapesessionbatch_id = "c"."id"
       INNER JOIN "transaction" e ON d.transactions_id = e."id"
       INNER JOIN tapefinancerecord f ON e."id" = f."id"
       INNER JOIN "public".modelbase ON "public".modelbase."id" = f."id"
       INNER JOIN taxaccumtotal "t" ON e.totaltax_id = "t"."id"
      WHERE  (e.isvoided = false or e.isvoided is null)
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

# This can be retrieved through table called as “SalesBaseTaxes” (where type = 12) for closeout.
