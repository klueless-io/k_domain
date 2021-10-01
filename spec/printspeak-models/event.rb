class Event < ActiveRecord::Base
  belongs_to :tenant

  def process
    result = ""
    if tenant.present?
      start_time = Time.now
      case event_type
      when "company_sales"
        company = Company.where(id: data["company_id"]).first
        if company
          company.generate_sales_stats
        end
      when "contact_sales"
        contact = Contact.where(id: data["contact_id"]).first
        if contact
          contact.generate_sales_stats
        end
      when "contact_rolling_sales"
        Contact.update_rolling_sales(tenant) if tenant
      when "sales_summary_perform_closeout"
        sales_summary = SalesSummary.where(id: data["sales_summary_id"]).first
        if sales_summary
          sales_summary.perform_closeout
        end
      when "sales_summary_current_accounting_period"
        sales_summary = SalesSummary.generate_current_month_stats(tenant) if tenant
      when "propagate_company_sales_reps"
        company = Company.where(id: data["company_id"]).first
        if company
          company.do_propagate_sales_reps
        end
      when "shipment_update"
        shipment = Shipment.where(id: data["shipment_id"]).first
        if shipment
          shipment.apply_source_tag
          shipment.invoice.update_deferred if shipment.invoice
          shipment.parent_invoice.update_deferred if shipment.parent_invoice
        end
      when "bubble_parent_tag"
        parent_tag = Tag.unscoped.where(id: data["parent_tag_id"]).first
        if parent_tag
          parent_tag.bubble
        end
      end
      end_time = Time.now
      EventStat.log(tenant, event_type, data, end_time - start_time, source)
    end
    destroy
  end

  # Doesn't 100% guarantee unqiueness of event in a parallel enviroment
  def self.queue(tenant, event_type, data: {}, schedule_date: nil, unique_for: ["all"], trace_back_count: 0)
    result = false

    unique_for = %w[running queued scheduled] if unique_for.include?("all")

    line_data = "unknown"
    caller_info = caller[trace_back_count].try(:split, ":")
    if caller_info
      caller_file = caller_info[0].gsub(/^#{Rails.root}/, "")
      caller_line_number = caller_info[1]
      line_data = "#{caller_file}:#{caller_line_number}"
    end

    status = "queued"
    if !schedule_date.nil?
      status = "scheduled"
    end

    unique_for_condition = "AND FALSE"

    if unique_for.count > 0
      sanitized_unqiue_for = unique_for.map { |s| ActiveRecord::Base::sanitize(s) }
      unique_for_condition = "AND status IN (#{sanitized_unqiue_for.to_csv})"
    end

    tenant_id = tenant.try(:id)

    create_event_query = %Q{
      INSERT INTO events (tenant_id, event_type, status, data, schedule_date, source, created_at, updated_at)
      SELECT #{ActiveRecord::Base::sanitize(tenant_id)},
      #{ActiveRecord::Base::sanitize(event_type)},
      #{ActiveRecord::Base::sanitize(status)},
      #{ActiveRecord::Base::sanitize(data.to_json)},
      #{ActiveRecord::Base::sanitize(schedule_date)},
      #{ActiveRecord::Base::sanitize(line_data)},
      NOW(),
      NOW()
      WHERE NOT EXISTS (
        SELECT null
        FROM events
        WHERE tenant_id = #{ActiveRecord::Base::sanitize(tenant_id)}
        AND event_type = #{ActiveRecord::Base::sanitize(event_type)}
        AND data = #{ActiveRecord::Base::sanitize(data.to_json)}
        #{unique_for_condition}
      )
      RETURNING id;
    }

    event_id = ActiveRecord::Base.connection.execute(create_event_query).try(:first).try(:[], "id")
    if !event_id.nil?
      result = true
    end

    result
  end

  def self.process_queued
    result = false
    event_query = %Q{
      UPDATE events
      SET status = 'running',
          updated_at = NOW()
      WHERE id = (
        SELECT id
        FROM events
        WHERE status = 'queued'
        ORDER BY created_at ASC
        LIMIT 1
        FOR UPDATE SKIP LOCKED
      )
      RETURNING id;
    }
    event_id = ActiveRecord::Base.connection.execute(event_query).first.try(:[], "id")
    event = nil
    event = Event.where(id: event_id).first if !event_id.nil?
    if event
      result = true
      event.process
    end

    result
  end

  def self.queue_scheduled
    scheduled_events_query = %Q{
      UPDATE events
      SET status = 'queued'
      WHERE status = 'scheduled'
      AND schedule_date <= NOW()
    }
    ActiveRecord::Base.connection.execute(scheduled_events_query)

    stalled_events_query = %Q{
      UPDATE events
      SET status = 'queued'
      WHERE status = 'running'
      AND updated_at <= (NOW() - interval '1 hour')
    }
    ActiveRecord::Base.connection.execute(stalled_events_query)

    nil
  end
end
