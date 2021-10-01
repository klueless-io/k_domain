# frozen_string_literal: true

class Workflow < ActiveRecord::Base
  default_scope { order(name: :asc) }

  belongs_to :tenant

  before_save :nullify_global_tenant_id

  validates :name, presence: { message: "Workflow name can't be blank (required)." }
  validates :name, length: { maximum: 250 }

  scope :by_tenant, -> (tenant) { where("workflows.tenant_id = ? OR (workflows.global = ? AND workflows.enterprise_id = ?)", tenant.id, true, tenant.enterprise.id).group("workflows.id") }
  scope :by_enterprise, -> (enterprise) { where(enterprise_id: enterprise.nil? ? -1 : enterprise.id) }

  def nullify_global_tenant_id
    self.tenant_id = nil if global
  end

  def user
    User.unscoped.where(id: user_id).try(:first) unless user_id.nil?
  end
end
