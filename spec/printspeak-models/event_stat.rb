class EventStat < ActiveRecord::Base
  belongs_to :tenant

  # CREATE INDEX CONCURRENTLY index_event_stats_on_created_at ON event_stats (created_at)
  # CREATE INDEX CONCURRENTLY index_event_stats_on_tenant_event_data_source_duration ON event_stats (tenant_id, event_type, data, source, duration ASC)

  def self.log(tenant, event_type, data, duration, source)
    EventStat.create(
      tenant: tenant,
      event_type: event_type,
      data: data,
      duration: duration.to_f,
      source: source
    )
  end

  def self.clean
    EventStat.where("event_stats.created_at < ?", 24.hours.ago).delete_all
  end

  def self.log_changed_attributes(tenant, object)
    object.attributes.each do |attr_name, attr_value|
      if object.send("#{attr_name}_changed?")
        data = {
          "#{object.class.to_s.downcase}_id".to_sym => object.id,
          attr_name: attr_name,
          attr_new_value: attr_value,
          attr_old_value: object.send("#{attr_name}_was")
        }
        Event.queue(tenant, "#{object.class.to_s.downcase}_attr_changed", data: data, trace_back_count: 1)
      end
    end
  end
end
