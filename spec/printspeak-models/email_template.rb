class EmailTemplate < ActiveRecord::Base
  require "fuzzystringmatch"

  # belongs_to :user
  belongs_to :tenant
  has_many :email_template_fields, dependent: :destroy
  has_many :email_template_categories, dependent: :destroy
  has_many :hidden_email_templates, dependent: :destroy
  belongs_to :wrapper, class_name: "EmailTemplate", foreign_key: "wrapper_id"



  before_save :nullify_global_tenant_id

  accepts_nested_attributes_for :email_template_fields, reject_if: lambda { |a| a[:name].blank? }, allow_destroy: true

  attr_accessor :hide

  scope :by_category, -> (tenant, categories) { joins("LEFT OUTER JOIN email_template_categories ON email_template_categories.email_template_id = email_templates.id").where("email_template_categories.category = ? OR email_templates.id = ?", categories.to_s.blank? ? 0 : categories.to_s, tenant.enterprise.default_email_template_id).distinct }
  scope :by_tenant, -> (tenant) { where(shell: false, hidden: false).where.not(archived: true).where("email_templates.tenant_id = ? OR (email_templates.global = ? AND email_templates.enterprise_id = ?)", tenant.id, true, tenant.enterprise.id).joins("LEFT OUTER JOIN hidden_email_templates ON hidden_email_templates.email_template_id = email_templates.id").having("? != ALL(array_agg(hidden_email_templates.tenant_id)) OR 0 = ALL(array_agg(COALESCE(hidden_email_templates.tenant_id, 0)))", tenant.id).group("email_templates.id") }
  scope :by_enterprise, -> (enterprise) { where(enterprise_id: enterprise.nil? ? -1 : enterprise.id) }
  scope :only_category, -> (categories) { joins("LEFT OUTER JOIN email_template_categories ON email_template_categories.email_template_id = email_templates.id").where("email_template_categories.category = ?", categories.to_s.blank? ? 0 : categories.to_s).distinct }
  default_scope { order(name: :asc) }

  validates :name, presence: true
  validates :name, length: { maximum: 250 }

  validates :subject, length: { maximum: 250 }

  validate :name_must_be_unique, :name_must_not_be_in_global

  def name_must_be_unique
    found_template = EmailTemplate.none
    if global
      found_template = EmailTemplate.where(global: false).where(name: name)
    else
      found_template = EmailTemplate.by_tenant(tenant).where(global: false).where(name: name)
    end
    found_template = found_template.where.not(id: id) if id.present?
    if found_template.first.present?
      errors.add(:name, "has already been taken by a local email template!")
    end
  end

  def name_must_not_be_in_global
    target_tenant = tenant
    target_tenant = user.primary_tenant if target_tenant.nil?
    found_template = EmailTemplate.by_enterprise(target_tenant.enterprise).where(global: true).where(name: name)
    found_template = found_template.where.not(id: id) if id.present?
    if found_template.first.present?
      errors.add(:name, "has already been taken by a global email template!")
    end
  end

  def user
    User.unscoped.where(id: user_id).try(:first) unless user_id.nil?
  end

  def categories
    email_template_categories.pluck(:category)
  end

  def categories=(new_categories)
    if new_categories.nil?
      email_template_categories.destroy_all
    else
      new_categories = new_categories.reject { |c| c.blank? }.map(&:to_i)
      if (new_categories - EmailTemplateCategory.platform_categories(@tenant).values).empty?
        email_template_categories.where.not(category: new_categories).destroy_all
        old_categories = email_template_categories.where(category: new_categories).pluck(:category)
        new_categories.each do |new_category|
          email_template_categories << EmailTemplateCategory.create!(category: new_category) unless old_categories.include?(new_category)
        end
      end
    end
  end

  def nullify_global_tenant_id
    self.tenant_id = nil if global
  end

  def self.default_for_location(context = nil)
    if context.present? && context.try(:production_location_id)
      if %w[estimates orders].include? context.class.to_s.pluralize.downcase
        by_tenant(context.tenant).by_category(context.tenant,  EmailTemplateCategory.platform_categories(@tenant)[context.class.to_s.pluralize.downcase.to_sym]).where(production_location_id: context.production_location_id).first
      end
    end
  end

  def update_similarities
    jarow = FuzzyStringMatch::JaroWinkler.create(:native)
    parent_template = EmailTemplate.where(id: copied_email_template_id).first
    if parent_template
      self.copied_similarity = jarow.getDistance(body, parent_template.body) * 100
      save
    end

    root_template = EmailTemplate.where(id: copied_root_email_template_id).first
    if root_template
      self.root_similarity = jarow.getDistance(body, root_template.body) * 100
      save
    end

    child_templates = EmailTemplate.where(copied_email_template_id: id, enterprise_id: enterprise_id)
    child_templates.each do |child_template|
      child_template.copied_similarity = jarow.getDistance(child_template.body, body) * 100
      child_template.save
    end

    root_child_templates = EmailTemplate.where(copied_root_email_template_id: id, enterprise_id: enterprise_id)
    root_child_templates.each do |root_child_template|
      root_child_template.root_similarity = jarow.getDistance(root_child_template.body, body) * 100
      root_child_template.save
    end
  end

  def include_roboto?(enterprise)
    (!try(:id) && enterprise.try(:default_roboto_font)) ||
    use_roboto ||
    try(:id) && enterprise.try(:default_roboto_font)
  end
end
