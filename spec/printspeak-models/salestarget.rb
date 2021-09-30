# frozen_string_literal: true

class Salestarget < ActiveRecord::Base
  extend RailsUpgrade

  enum target_type: { Leads: 1, Accounts: 2, Activity: 3, "Lead Types": 4 }
  belongs_to :user

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  def user_target(user_id)
    Salestarget.where(tenant_id: tenant_id, target_type: self[:target_type], name: name, user_id: user_id).first.try(:amount)
  end
end
