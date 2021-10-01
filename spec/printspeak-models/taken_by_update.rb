# frozen_string_literal: true

class TakenByUpdate < ActiveRecord::Base
  extend RailsUpgrade

  self.table_name = "taken_by_updates"

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  belongs_to :taken_by, **belongs_to_required
  validates :taken_by, presence: { message: "must exist" } if rails4?

  def update_contexts
    invoices_query = %Q{
      UPDATE invoices
      SET taken_by_user_id = #{taken_by.user_id || 'NULL'}
      WHERE tenant_id = #{tenant.id}
      AND source_taken_by = #{ActiveRecord::Base::sanitize(taken_by.name)}
    }

    estimates_query = %Q{
      UPDATE estimates
      SET taken_by_user_id = #{taken_by.user_id || 'NULL'}
      WHERE tenant_id = #{tenant.id}
      AND source_taken_by = #{ActiveRecord::Base::sanitize(taken_by.name)}
    }

    if !taken_by.name.blank?
      ActiveRecord::Base.connection.execute(invoices_query)
      ActiveRecord::Base.connection.execute(estimates_query)
    end

    delete
  end

  def self.update_taken_bys
    TakenByUpdate.all.order(created_at: :asc).each do |taken_by_update|
      taken_by_update.update_contexts
    end
  end

  # TakenRepUpdate.create!(tenant_id: tenant.id, taken_by_id: taken_by.id)
end
