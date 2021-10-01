# frozen_string_literal: true

class TaskType < ActiveRecord::Base
  default_scope {
    order(name: :asc)
  }
  scope :visible, -> (tenant) {
    joins("LEFT JOIN hidden_task_types ON hidden_task_types.task_type_id = task_types.id AND hidden_task_types.tenant_id = #{tenant.id}")
    .where("hidden_task_types.task_type_id IS NULL")
  }

  scope :by_tenant_all, ->(tenant) {
    where(enterprise_id: tenant.enterprise_id).where("task_types.global = ? OR task_types.tenant_id = ?", true, tenant.id)
  }

  # CHAIN SCOPE TENANT VISIBLE
  class << self
    def tenant(tenant)
      by_tenant_all(tenant).visible(tenant)
    end
  end

  has_many :hidden_task_types, dependent: :destroy
  belongs_to :tenant
  belongs_to :enterprise
  belongs_to :user
  has_many :tasks

  after_destroy { |record| record.tasks.update_all(task_type_id: nil) }

  # VALIDATIONS

  validates :name, presence: { message: "Task type name is required." }
end
