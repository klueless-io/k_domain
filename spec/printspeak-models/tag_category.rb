class TagCategory < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :enterprise
  has_many :contexts, class_name: "TagCategoryContext", dependent: :destroy
  has_many :tags, dependent: :destroy


  attr_accessor :global

  default_scope { where(hidden: false, performing_cleanup: false, deleted: false) }
  scope :by_tenant, -> (tenant) { where("(tag_categories.tenant_id = ? OR tag_categories.tenant_id IS NULL) AND tag_categories.enterprise_id = ?", tenant.id, tenant.enterprise_id) }
  scope :without_hidden, -> (tenant) { where("(tag_categories.hidden_tenants->>'#{tenant.id}')::BOOLEAN IS DISTINCT FROM TRUE") }
  scope :global_only, -> { where("tag_categories.tenant_id IS NULL") }

  def scan(limit)
    return 0 if performing_cleanup || deleted || word_matches.split(",").count == 0
    filters = word_matches.split(",").map { |s| "#{s.squish}" }.reject { |s| s.blank? }.join("|")
    filters = ActiveRecord::Base::sanitize("\\y(#{filters})")
    limit_remaning = limit
    contexts.each do |context|
      break if limit_remaning <= 0
      target_tenant_ids = [tenant_id]
      target_tenant_ids = enterprise.tenants.pluck(:id) if tenant_id.nil?

      target_tenant_ids.each do |target_tenant_id|
        # WorkerDaemon.log("  [2]Starting category scan #{self.name}(#{self.id}) for tenant #{target_tenant_id} on #{context.name}")
        break if limit_remaning <= 0
        scan_progress = context.scan_progress["#{target_tenant_id}"]

        if scan_progress.nil?
          scan_progress = {
            last_scanned_id: 0,
            last_scanned_offset: 0,
            last_scanned: nil
          }
        end

        scan_progress = scan_progress.with_indifferent_access

        first_updated_at = nil
        last_updated_at = Time.now
        last_id = nil
        scan_cutoff = scan_progress[:last_scanned].nil? ? "2014-01-01" : scan_progress[:last_scanned]
        objects = "#{context.name}".restricted_constantize(PrintSpeak::Application.config.common_context_types)
        objects = objects.where(tenant_id: target_tenant_id)
        objects = objects.where("#{context.name.pluralize}.source_updated_at >= ?", scan_cutoff)

        object_count = objects.count

        next if object_count == 0

        objects = objects.where("(#{context.name.pluralize}.name ~* #{filters} OR #{context.name.pluralize}.job_descriptions ~* #{filters})")
        # WorkerDaemon.log("    [3]Object Query Start")
        objects = objects.order(source_updated_at: :asc).limit(limit_remaning).offset(scan_progress[:last_scanned_offset]).to_a
        # WorkerDaemon.log("    [3]Object Query Finish")
        # WorkerDaemon.log("    [4]Updating #{objects.count} objects")
        objects.each do |object|
          real_object = context.name.restricted_constantize(PrintSpeak::Application.config.common_context_types).where(id: object.id).first
          tag_context(real_object, manual: false) if real_object
          first_updated_at = object.source_updated_at if first_updated_at.nil?
          last_updated_at = object.source_updated_at
          last_id = object.id
        end
        # WorkerDaemon.log("    [4]Finsihed updating #{objects.count} objects")

        scan_progress[:last_scanned] = last_updated_at
        if scan_progress[:last_scanned_id] == last_id
          scan_progress[:last_scanned] += 1.second
          scan_progress[:last_scanned_offset] = 0
        else
          if first_updated_at == last_updated_at && objects.count > 0
            scan_progress[:last_scanned_offset] += limit_remaning
          else
            scan_progress[:last_scanned_offset] = 0
          end
        end

        scan_progress[:last_scanned_id] = last_id

        context.scan_progress["#{target_tenant_id}"] = scan_progress
        context.save

        limit_remaning -= objects.count
      end
    end
    limit - limit_remaning
  end

  def cleanup(limit)
    return 0 unless performing_cleanup

    tag_ids = []
    if deleted
      tag_ids = Tag.unscoped.where(tag_category_id: id).limit(limit).pluck(:id)
    else
      Tag.unscoped.where(tag_category_id: id, manual: false).where("user_id IS NOT NULL").update_all(manual: true)
      tag_ids = Tag.unscoped.where(tag_category_id: id, manual: false).limit(limit).pluck(:id)
    end

    if tag_ids.count > 0
      Tag.unscoped.where(id: tag_ids).delete_all
    else
      if deleted
        destroy
      else
        self.performing_cleanup = false
        reset_contexts
        save
      end
    end

    tag_ids.count
  end

  def local_hide(tenant, hidden_state = true)
    hidden_tenants[tenant.id] = hidden_state
    save
  end

  def tag_context(context, user_id: nil, manual: true, parent_tag: nil, deleted: false)
    if context.id.nil?
      raise "You should not create tags for contexts that have not yet been saved to the database."
    end

    parent_tag_id = nil
    parent_tag_id = parent_tag.id if !parent_tag.nil?
    tag = Tag.unscoped.find_or_initialize_by(tenant_id: context.tenant_id, taggable: context, tag_category_id: id, parent_id: parent_tag_id)
    if deleted
      if !tag.id.nil? && !tag.deleted && (tag.manual || !manual)
        tag.user_id = user_id if !user_id.nil?
        tag.deleted = true
        tag.parent_id = nil
        tag.manual = manual
        tag.save
        Event.queue(tag.tenant, "bubble_parent_tag", data: {parent_tag_id: tag.id}) if parent_tag.nil?
      end
    else
      if tag.id.nil? || tag.deleted || !manual
        tag.user_id = user_id if !user_id.nil?
        tag.parent_id = parent_tag.id if !parent_tag.nil?
        tag.deleted = false
        tag.manual = manual
        tag.save
        Event.queue(tag.tenant, "bubble_parent_tag", data: {parent_tag_id: tag.id}) if parent_tag.nil?
      end
    end
  end

  def reset_contexts
    contexts = %w[Estimate Invoice]
    self.contexts.destroy_all
    contexts.each do |context|
      self.contexts.create(name: context)
    end
  end

  def self.filter_by_contexts(target_tenant, contexts, category_ids, include = "1")
    context_type = contexts.model.to_s
    context_type = "Invoice" if %w[Sale Order].include?(context_type)
    table_name = contexts.model.table_name
    sub_query = %Q{
      EXISTS (
        SELECT null
        FROM tag_categories
        INNER JOIN tags ON tag_categories.id = tags.tag_category_id
          AND tags.deleted = FALSE
        WHERE
          tag_categories.id IN (#{category_ids.to_csv})
          AND tag_categories.performing_cleanup = FALSE
          AND tag_categories.deleted = FALSE
          AND ( ( tag_categories.tenant_id = #{target_tenant.id} OR tag_categories.tenant_id IS NULL ) AND tag_categories.enterprise_id = #{target_tenant.enterprise_id} )
          AND tags.tenant_id = #{target_tenant.id}
          AND tags.taggable_type = '#{context_type}'
          AND tags.taggable_id = #{table_name}.id
      )
    }

    if include == "1"
      contexts.where(sub_query)
    else
      contexts.where.not(sub_query)
    end
  end
end
