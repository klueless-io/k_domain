class ProspectStatusItemContact < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :contact
  belongs_to :prospect_status_item


  enum activity_status: {
    "In Progress": 2,
    "Completed": 1,
    "Skipped": 3
  }

  def trigger_next(current_user)
    @next_item = prospect_status_item.lower_item

    if @next_item.present?
      # CURRENT STATUS NEXT ITEM
      if !ProspectStatusItemContact.where(prospect_status_item_id: @next_item.id, contact_id:  contact_id, tenant_id: id).first
        prospect_status_item_contact = ProspectStatusItemContact.create(
          contact_id: contact_id,
          start_date: Time.zone.now() + (@next_item.start_after_days.try(:days) || 0),
          due_date: Time.zone.now() + (@next_item.start_after_days.try(:days) || 0) + @next_item.try(:completion_time).days,
          prospect_status_item_id: @next_item.id,
          tenant_id: tenant_id,
          status: 2
        )

        prospect_status_item_contact.task_generate(current_user) if prospect_status_item_contact.prospect_status_item.item_type == "Task"
        prospect_status_item_contact.meeting_generate(current_user) if prospect_status_item_contact.prospect_status_item.item_type == "Meeting"
      end
    else

      # GET NEXT AVAILABLE STATUS
      @next_status = contact.next_available_status

      # FIX IF STATUS HAS NO ITEMS OR STATUS IS HIDDEN IN CURRENT LEAD TYPE
      if @next_status.present?
        @next_item = ProspectStatusItem.where(prospect_status_id: @next_status.id, lead_type_id: contact.lead_type_id).first

        c = Contact.find(contact_id)
        c.prospect_status_id =  @next_status.id
        c.save
      end

      if @next_item.present?


        if  !ProspectStatusItemContact.where(prospect_status_item_id: @next_item.id, contact_id:  contact_id, tenant_id: tenant_id).first
          prospect_status_item_contact = ProspectStatusItemContact.create(
            contact_id: contact_id,
            start_date: Time.zone.now() + (@next_item.start_after_days.try(:days) || 0),
            due_date: Time.zone.now() + (@next_item.start_after_days.try(:days) || 0)+ @next_item.try(:completion_time).days,
            prospect_status_item_id: @next_item.id,
            tenant_id: tenant_id,
            status: 2
          )

          prospect_status_item_contact.task_generate(current_user) if prospect_status_item_contact.prospect_status_item.item_type == "Task"
          prospect_status_item_contact.meeting_generate(current_user) if prospect_status_item_contact.prospect_status_item.item_type == "Meeting"
        end

      end


    end

    Contact.find(contact_id).compute_activity_progress
  end

  def task_generate(current_user)
    task = Task.new
    task.status = "Open"
    task.name = prospect_status_item.name
    task.description = translated_message(current_user, prospect_status_item.description) if prospect_status_item.description
    task.taskable_type = "Contact"
    task.taskable_id = contact_id
    task.tenant_id = contact.tenant_id
    task.prospect_status_item_contact_id = id
    task.assigned_user_id = contact.try(:sales_rep).try(:user_id) || contact.try(:company).try(:sales_rep).try(:user_id)
    task.user_id = current_user.id
    task.start_date = start_date
    task.end_date = due_date
    task.save!

    # RECORD ACTIVITY?
    activity_attrs = {
      user_id: current_user.id,
      tenant_id: task.tenant_id,
      task: task,
      activity_for: "task"
    }

    activity_attrs = Activity.add_contextual_attribute(activity_attrs, task.taskable)

    Activity.create!(activity_attrs)
    # END RECORD
  end

  def meeting_generate(current_user)
    meeting = Meeting.new
    meeting.title = prospect_status_item.name

    if prospect_status_item.description
      meeting.note = translated_message(current_user, prospect_status_item.description)
    else
      meeting.note = " "
    end

    meeting.created_at = Time.zone.now
    meeting.attendees.build(user_id: current_user.id)
    meeting.attendees.build(contact_id: contact_id)

    meeting.user_id = current_user.id
    meeting.tenant_id = contact.tenant_id
    meeting.context_id = contact_id
    meeting.context_type = "Contact"
    meeting.prospect_status_item_contact_id = id

    meeting.start_date = start_date
    meeting.end_date = due_date
    meeting.status = "draft"

    # meeting.calendar_needs_update = true
    # meeting.update_calendar if @meeting.calendar_needs_update
    # meeting.notify_creator

    meeting.save!

    # RECORD ACTIVITY?
    activity_attrs = {
      user_id: current_user.id,
      tenant_id: meeting.tenant_id,
      meeting_id: meeting.id,
      activity_for: "meeting_created"
    }
    activity_attrs = Activity.add_contextual_attribute(activity_attrs, meeting.context)
    Activity.create!(activity_attrs)
    # END RECORD
  end

  def translated_message(current_user, message)
    template_merger = TemplateMerger.new(self, current_user, tenant, try(:contact))
    template_merger.translated_body(message)
  end
end