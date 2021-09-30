class SmsTemplate < ActiveRecord::Base
  default_scope { order(name: :asc) }

  belongs_to :enterprise
  belongs_to :tenant
  belongs_to :user
  # has_many :sms_template_fields, dependent: :destroy
  has_many :sms_template_categories, dependent: :destroy
  belongs_to :wrapper, class_name: "SmsTemplate", foreign_key: "wrapper_id"



  before_save :nullify_global_tenant_id

  validates :name, presence: true
  validates :name, length: { maximum: 250 }

  validates :body, presence: true

  scope :by_category, -> (tenant, categories) { joins("LEFT OUTER JOIN sms_template_categories ON sms_template_categories.sms_template_id = sms_templates.id").where("sms_template_categories.category = ?", categories.to_s.blank? ? 0 : categories.to_s) }
  scope :by_tenant, -> (tenant) { where("sms_templates.tenant_id = ? OR (sms_templates.global = ? AND sms_templates.enterprise_id = ?)", tenant.id, true, tenant.enterprise.id).group("sms_templates.id") }
  scope :by_enterprise, -> (enterprise) { where(enterprise_id: enterprise.nil? ? -1 : enterprise.id) }

  def nullify_global_tenant_id
    self.tenant_id = nil if global
  end

  def user
    User.unscoped.where(id: user_id).try(:first) unless user_id.nil?
  end

  def categories
    sms_template_categories.pluck(:category)
  end

  def categories=(new_categories)
    if new_categories.nil?
      sms_template_categories.destroy_all
    else
      new_categories = new_categories.reject { |c| c.blank? }.map(&:to_i)
      if (new_categories - SmsTemplateCategory.categories.values).empty?
        sms_template_categories.where.not(category: new_categories).destroy_all
        old_categories = sms_template_categories.where(category: new_categories).pluck(:category)
        new_categories.each do |new_category|
          sms_template_categories << SmsTemplateCategory.create!(category: new_category) unless old_categories.include?(new_category)
        end
      end
    end
  end
end
