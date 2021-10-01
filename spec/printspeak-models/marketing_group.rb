class MarketingGroup < ActiveRecord::Base
  def email_templates
    result = EmailTemplate.none

    if email_template_ids && email_template_ids.count > 0
      result = EmailTemplate.where("email_templates.id IN (#{email_template_ids.join(',')}) OR email_templates.copied_email_template_id IN (#{email_template_ids.join(',')}) OR email_templates.copied_root_email_template_id IN (#{email_template_ids.join(',')})")
                            .where("email_templates.copied_similarity >= 85 OR email_templates.id IN (#{email_template_ids.join(',')})")
                            .reorder("COALESCE((SELECT name FROM email_templates e WHERE e.id = email_templates.copied_root_email_template_id), email_templates.name) ASC, email_templates.copied_email_template_id ASC, email_templates.name ASC")
      if excluded_email_template_ids && excluded_email_template_ids.count > 0
        result = result.where.not(id: excluded_email_template_ids)
      end
    end

    result
  end

  def matched_campaigns
    result = Campaign.none

    email_template_ids = email_templates.map(&:id)

    if email_template_ids && email_template_ids.count > 0
      result = Campaign.where(email_template_id: email_template_ids, parent_id: nil, enterprise_id: enterprise_id).order(name: :asc)
    end

    result
  end

  def manual_campaigns
    result = Campaign.none

    if campaign_ids && campaign_ids.count > 0
      result = Campaign.where(id: campaign_ids, enterprise_id: enterprise_id).order(name: :asc)
    end

    result
  end

  def excluded_campaigns
    result = Campaign.none

    if excluded_campaign_ids && excluded_campaign_ids.count > 0
      result = Campaign.where(id: excluded_campaign_ids, enterprise_id: enterprise_id).order(name: :asc)
    end

    result
  end

  def campaigns(sent=false)
    campaigns_condition = "FALSE"
    if campaign_ids.count > 0
      if sent
        campaigns_condition = "campaigns.parent_id IN (#{campaign_ids.join(",")})"
      else
        campaigns_condition = "campaigns.id IN (#{campaign_ids.join(",")})"
      end
    end

    email_templates_condition = "FALSE"
    email_template_ids = email_templates.pluck(:id)
    if email_template_ids.count > 0
      email_templates_condition = "campaigns.email_template_id IN (#{email_template_ids.join(",")})"
    end

    excluded_campaigns_condition = ""
    if excluded_campaign_ids.count > 0
      if sent
        excluded_campaigns_condition = "AND campaigns.parent_id NOT IN (#{excluded_campaign_ids.join(",")})"
      else
        excluded_campaigns_condition = "AND campaigns.id NOT IN (#{excluded_campaign_ids.join(",")})"
      end
    end

    sent_condition = ""
    if sent
      sent_condition = " NOT"
    end

    campaigns_query = %Q{
      SELECT *
      FROM campaigns
      WHERE campaigns.parent_id IS#{sent_condition} NULL
      AND campaigns.test = FALSE
      AND (
        #{campaigns_condition}
        OR
        #{email_templates_condition}
      )
      #{excluded_campaigns_condition}
      ORDER BY campaigns.name ASC
    }
    Campaign.find_by_sql(campaigns_query)
  end

  def self.search(search, enterprise_id, page: 1, per: 20)
    query = %Q{
      SELECT *, (COUNT(*) OVER()) AS total_count
      FROM marketing_groups
      WHERE marketing_groups.enterprise_id = #{enterprise_id}
      AND marketing_groups.name ILIKE #{ActiveRecord::Base::sanitize("%#{search}%")}
      OR EXISTS
      (
      SELECT null
      FROM campaigns
      WHERE campaigns.parent_id IS NULL
      AND campaigns.test = FALSE
      AND campaigns.name ILIKE #{ActiveRecord::Base::sanitize("%#{search}%")}
      AND (
        ARRAY[campaigns.id] && marketing_groups.campaign_ids
        OR
        campaigns.email_template_id IN (
          SELECT email_templates.id
          FROM email_templates
          WHERE (
            ARRAY[email_templates.id] && marketing_groups.email_template_ids
            OR ARRAY[email_templates.copied_email_template_id] && (marketing_groups.email_template_ids)
            OR ARRAY[email_templates.copied_root_email_template_id] && (marketing_groups.email_template_ids)
          )
          AND (
            email_templates.copied_similarity >= 85
            OR ARRAY[email_templates.id] && marketing_groups.email_template_ids
          )
          AND NOT (ARRAY[email_templates.id] && marketing_groups.excluded_email_template_ids)
        )
      )
      AND NOT (ARRAY[campaigns.id] && marketing_groups.excluded_campaign_ids)
      )
      ORDER BY marketing_groups.name ASC
      LIMIT #{per.to_i}
      OFFSET #{(page.to_i-1) * per.to_i}
    }

    results = MarketingGroup.find_by_sql(query)
    Kaminari.paginate_array(results, total_count: results.first.try(:total_count) || 0).page(page).per(per)
  end
end