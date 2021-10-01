# frozen_string_literal: true

class ProspectStatus < ActiveRecord::Base
  default_scope { order(position: :asc) }

  belongs_to :enterprise
  belongs_to :tenant, -> { where(enterprise_id: 0, lead_type_id: 0).order(name: :asc) }
  belongs_to :lead_type
  belongs_to :prospect_status_version
  belongs_to :contact
  has_many :prospect_status_items
  has_one :enterprise_salestarget

  # rubocop:disable Lint/InterpolationCheck
  # @Discuss what is this about?
  acts_as_list scope: 'lead_type_id = #{lead_type_id} AND tenant_id = #{tenant_id} AND prospect_status_version_id = #{prospect_status_version_id} AND enterprise_id = #{enterprise_id}'
  # rubocop:enable Lint/InterpolationCheck

  validates :name, presence: { message: "Status name can't be blank (required)." }
  validates :name, length: { maximum: 250 }

  validate :check_valid_lead_stage

  def check_valid_lead_stage
    if lead_type_id != 0 && ProspectStatus.where(lead_type_id: lead_type_id, name: name, prospect_status_version_id: prospect_status_version_id).first
      errors.add(:name, "lead stage is already created.")
    end
  end

  def user
    User.unscoped.where(id: user_id).try(:first) unless user_id.nil?
  end

  def sales_target(tenant)
    Salestarget.where(tenant_id: tenant.id, target_type: 1, name: name, user_id: nil).first
  end
end
