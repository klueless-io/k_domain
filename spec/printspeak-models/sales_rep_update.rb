class SalesRepUpdate < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  belongs_to :sales_rep, **belongs_to_required
  validates :sales_rep, presence: { message: "must exist" } if rails4?

  def update_contexts
    target_sales_rep = SalesRep.unscoped.find(sales_rep_id)
    invoices_query = %Q{
      UPDATE invoices
      SET sales_rep_user_id = #{target_sales_rep.user_id || 'NULL'}, location_user_id = #{target_sales_rep.location_id || 'NULL'}
      WHERE tenant_id = #{tenant.id}
      AND sales_rep_platform_id = '#{target_sales_rep.platform_id}'
    }

    estimates_query = %Q{
      UPDATE estimates
      SET sales_rep_user_id = #{target_sales_rep.user_id || 'NULL'}, location_user_id = #{target_sales_rep.location_id || 'NULL'}
      WHERE tenant_id = #{tenant.id}
      AND sales_rep_platform_id = '#{target_sales_rep.platform_id}'
    }

    shipments_query = %Q{
      UPDATE shipments
      SET sales_rep_user_id = #{target_sales_rep.user_id || 'NULL'}, location_user_id = #{target_sales_rep.location_id || 'NULL'}
      WHERE tenant_id = #{tenant.id}
      AND sales_rep_platform_id = '#{target_sales_rep.platform_id}'
    }

    contacts_query = %Q{
      UPDATE contacts
      SET sales_rep_user_id = #{target_sales_rep.user_id || 'NULL'}, location_user_id = #{target_sales_rep.location_id || 'NULL'}
      WHERE tenant_id = #{tenant.id}
      AND sales_rep_platform_id = '#{target_sales_rep.platform_id}'
    }

    companies_query = %Q{
      UPDATE companies
      SET sales_rep_user_id = #{target_sales_rep.user_id || 'NULL'}, location_user_id = #{target_sales_rep.location_id || 'NULL'}
      WHERE tenant_id = #{tenant.id}
      AND sales_rep_platform_id = '#{target_sales_rep.platform_id}'
    }

    adjustments_query = %Q{
      UPDATE adjustments
      SET sales_rep_user_id = #{target_sales_rep.user_id || 'NULL'}, location_user_id = #{target_sales_rep.location_id || 'NULL'}
      WHERE tenant_id = #{tenant.id}
      AND (
        invoice_id IN (
          SELECT id
          FROM invoices
          WHERE tenant_id = #{tenant.id}
          AND sales_rep_platform_id = '#{target_sales_rep.platform_id} '
        )
        OR
        company_id IN (
          SELECT id
          FROM companies
          WHERE tenant_id = #{tenant.id}
          AND sales_rep_platform_id = '#{target_sales_rep.platform_id} '
        )
      )
    }

    ActiveRecord::Base.connection.execute(invoices_query)
    ActiveRecord::Base.connection.execute(estimates_query)
    ActiveRecord::Base.connection.execute(contacts_query)
    ActiveRecord::Base.connection.execute(companies_query)
    ActiveRecord::Base.connection.execute(adjustments_query)

    delete
  end

  def self.update_sales_reps
    SalesRepUpdate.all.order(created_at: :asc).each do |sales_rep_update|
      sales_rep_update.update_contexts
    end
  end

  # SalesRepUpdate.create!(tenant_id: tenant.id, sales_rep_id: sales_rep.id)
end
