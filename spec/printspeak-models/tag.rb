class Tag < ActiveRecord::Base
  belongs_to :user
  belongs_to :tenant
  belongs_to :taggable, polymorphic: true
  belongs_to :tag_category
  belongs_to :parent, class_name: "Tag", foreign_key: "parent_id"
  has_many :children, class_name: "Tag", foreign_key: "parent_id"



  default_scope { where(deleted: false) }

  scope :without_hidden, -> (tenant) { joins(:tag_category).where("(tag_categories.hidden_tenants->>'#{tenant.id}')::BOOLEAN IS DISTINCT FROM TRUE") }

  def tag_name
    tag_category.try(:name) || name
  end

  def bubble
    return if !tag_category
    if parent
      parent.bubble
    else
      if taggable.class == Company
        bubble_to_company_contacts(taggable.id)
      elsif taggable.class == Contact
        bubble_to_company(taggable.company_id)
      elsif taggable.class == Estimate || taggable.class == Invoice || taggable.class == Sale || taggable.class == Order || taggable.class == Shipment || taggable.class == Inquiry
        bubble_to_contact(taggable.contact_id)
      elsif taggable.class == Campaign
        bubble_to_campaign_contacts(taggable.id)
      end
      self.bubbled = true
      save
    end
  end

  def self.for_context(context, only_own = false)
    result = Tag.without_hidden(context.tenant).
                 where(tenant_id: context.tenant.id, taggable: context).
                 order(tag_category_id: :desc)
    result = result.where(parent_id: nil) if only_own
    result
  end

  def self.for_context_other(context)
    Tag.without_hidden(context.tenant)
       .where(tenant_id: context.tenant.id, taggable: context)
       .where.not(parent_id: nil)
       .order(tag_category_id: :desc)
  end

  def self.bulk_all(context_type, target_tenant, target_ids, category_ids, manual = false)
    Tag.where(tenant_id: target_tenant.id).
        where(taggable_type: context_type.to_s, taggable_id: target_ids).
        where(manual: manual).
        where(tag_category_id: category_ids)
  end

  private
    def bubble_to_contact(contact_id)
      contact = Contact.unscoped.where(id: contact_id).first
      if contact
        tag_category.tag_context(contact, user_id: user_id, manual: manual, deleted: deleted, parent_tag: self)
        bubble_to_company(contact.company_id)
      end
    end

    def bubble_to_company_contacts(company_id)
      contacts = Contact.unscoped.where(company_id: company_id)
      contacts.each do |contact|
        tag_category.tag_context(contact, user_id: user_id, manual: manual, deleted: deleted, parent_tag: self)
      end
    end

    def bubble_to_company(company_id)
      company = Company.unscoped.where(id: company_id).first
      if company
        tag_category.tag_context(company, user_id: user_id, manual: manual, deleted: deleted, parent_tag: self)
      end
    end

    def bubble_to_campaign_contacts(campaign_id)
      campaign = Campaign.unscoped.where(id: campaign_id).first
      if campaign
        campaign.active_contacts.each do |contact|
          tag_category.tag_context(contact, user_id: user_id, manual: manual, deleted: deleted, parent_tag: self)
        end
      end
    end
end
