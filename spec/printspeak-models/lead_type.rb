# frozen_string_literal: true

class LeadType < ActiveRecord::Base
  default_scope { order("LOWER(lead_types.name) ASC") }

  validate :name_unique

  scope :visible, -> {
    includes(:hidden_lead_types)
    .where(hidden_lead_types: { lead_type: nil })
  }

  scope :active, -> {
    where.not(status: [2, 3, 4])
    .order(name: :asc)
  }

  scope :by_tenant, -> (tenant) { where.not(status: [2, 3, 4]).where("lead_types.tenant_id = ? OR (lead_types.global = ? AND lead_types.enterprise_id = ?)", tenant.id, true, tenant.enterprise.id).joins("LEFT OUTER JOIN hidden_lead_types ON hidden_lead_types.lead_type_id = lead_types.id").having("? != ALL(array_agg(hidden_lead_types.tenant_id)) OR 0 = ALL(array_agg(COALESCE(hidden_lead_types.tenant_id, 0)))", tenant.id).joins(:prospect_statuses).group("lead_types.id") }
  scope :by_tenant_old, -> (tenant) { where(status: 4).where("lead_types.tenant_id = ? OR (lead_types.global = ? AND lead_types.enterprise_id = ?)", tenant.id, true, tenant.enterprise.id).joins(:prospect_statuses).group("lead_types.id")  }
  scope :by_tenant_archived, -> (tenant) {
    where(status: 3).where("lead_types.tenant_id = ? OR (lead_types.global = ? AND lead_types.enterprise_id = ?)", tenant.id, true, tenant.enterprise.id)
    .joins(:prospect_status_version)
    .joins(:prospect_statuses)
    .joins("LEFT JOIN prospect_status_items ON prospect_status_items.prospect_status_id = prospect_statuses.id AND prospect_status_items.lead_type_id = lead_types.id").where.not('prospect_status_items.id': nil)
    .group("lead_types.id")
  }

  enum status: { Live: 1, Draft: 2, Archived: 3, Old: 4 }

  belongs_to :enterprise
  belongs_to :tenant
  has_many :prospect_status_items
  has_many :prospect_status_versions
  has_many :contacts

  belongs_to :prospect_status_version, class_name: "ProspectStatusVersion", foreign_key: "active_status_version"

  has_many :prospect_statuses, dependent: :destroy
  has_many :hidden_lead_types, dependent: :destroy

  has_one :enterprise_salestarget

  def first_active_status
    prospect_status_version.prospect_statuses.first
  end

  def sales_target(tenant)
    Salestarget.where(tenant_id: tenant.id, target_type: 4, name: name, user_id: nil).first
  end

  def name_unique
    if global == true
      matching_lead_types = LeadType.unscoped.where(enterprise_id: enterprise.id).where(global: true).where.not(status: [3, 4]).where(name: name).where.not(id: id).count
    else
      matching_lead_types = LeadType.unscoped.where(enterprise_id: enterprise.id).where.not(status: [3, 4]).where(name: name).where.not(id: id).count
    end

    if matching_lead_types > 0
      errors.add(:name, "Lead Type name must be unique")
    end
  end
end
