class Enterprise < ActiveRecord::Base
  has_many :tenants
  has_and_belongs_to_many :countries
  has_many :enterprise_togglefields
  has_many :news
  has_many :groups
  has_many :campaigns
  has_many :contact_lists
  has_many :task_types
  has_many :workflows
  has_many :interest_categories
  has_many :prospect_statuses, -> { where(lead_type_id: 0, tenant_id: 0, prospect_status_version_id: 0).order(name: :asc) }



  has_many :enterprise_salestargets
  has_many :enterprise_business_welcomes
  has_many :lead_types, -> { where(tenant_id: nil, global: true) }
  has_many :lead_sources
  has_many :holidays
  has_many :prospect_status_items
  has_many :tag_categories
  has_one :default_group, -> { where(default: true) }, class_name: "Group"

  default_scope { where(deleted_at: nil) }

  def banner
    Asset.where(id: banner_id, enterprise_id: id, category: "Banner").first
  end

  def self.connection_types
    %w[printsmith mbehub]
  end

  def users
    User.where(enterprise_id: id).order(first_name: :asc)
  end

  def primary_users
    users.where("users.parent_id = users.id")
  end

  def visible_users
    primary_users.where(role: ["User", "Admin", "Enterprise User"])
  end

  def default_tenant
    result = nil

    result = tenants.enabled.where(id: default_tenant_id).first if default_tenant_id.present?
    result = tenants.enabled.where(demo: true).first if result.nil?
    result = tenants.enabled.first if result.nil?
    result = tenants.first if result.nil?

    result
  end

  def is_AGI?
   return true if ((RegionConfig.get_value("region") == "us" && id == 3) || Rails.env.staging? || Rails.env.development?)
  end

  # AFTER CREATE GENERATE DEFAULT TASKS FOR ENTERPRISE ID
  # eg. rake generate:tasktypes[14]

  # TODO: FIX TO GET THE FIRST AVAILABLE LEAD STATUS

  def first_prospect_status
    prospect_statuses.where(position: 1).first
  end

  def first_lead_type
    lead_types.active.first
  end

  # available lead stages
  def available_lead_statuses(lead_type_id)
    lead_type = lead_types.where(id: lead_type_id).first
    lead_type.lead_status_visibility.present? ? prospect_statuses.where(id: lead_type.lead_status_visibility) : prospect_statuses
    # self.prospect_statuses.where(lead_type_id: nil)
  end

  def invoice_types
    result = {}

    if platform_data && platform_data["invoice_types"]
      invoice_types = platform_data["invoice_types"]
      invoice_types.sort_by! { |invoice_type| invoice_type["position"] }
      invoice_types.each do |invoice_type|
        result[invoice_type["id"]] = invoice_type["name"]
      end
    end

    result
  end

  def invoiced_types
    result = []

    if platform_data && platform_data["invoice_types"]
      invoice_types = platform_data["invoice_types"]
      result = invoice_types.map { |invoice_type| invoice_type["id"] if invoice_type["invoiced"] }.compact
    end

    result
  end

  def deferred_types
    result = []

    if platform_data && platform_data["invoice_types"]
      invoice_types = platform_data["invoice_types"]
      result = invoice_types.map { |invoice_type| invoice_type["id"] if invoice_type["deferred"] }.compact
    end

    result
  end

  def royalty_types
    result = {}

    if platform_data && platform_data["royalty_types"]
      result = platform_data["royalty_types"]
    end

    result
  end

  def mbe_services
    result = {}

    if platform_data && platform_data["mbe_services"]
      result = platform_data["mbe_services"]
    end

    result
  end

  def privacy_types
    result = []

    if platform_data && platform_data["privacy_types"]
      result = platform_data["privacy_types"].sort_by { |k, v| [v[0], k] }.map { |k, v| k }
    end

    result
  end

  def privacy_type_id(type_id)
    result = nil

    if platform_data && platform_data["privacy_types"]
      platform_data["privacy_types"].each do |k, v|
        if v && v.include?(type_id)
          result = k
          break
        end
      end
    end

    result
  end

  def business_plan_marketing_activities
    BusinessPlanMarketingActivity.where(global: true, enterprise_id: self.id).all
  end
end
