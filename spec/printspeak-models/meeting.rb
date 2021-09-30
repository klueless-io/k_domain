class Meeting < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :user
  belongs_to :context, polymorphic: true
  has_many :attendees, inverse_of: :meeting, class_name: "MeetingAttendee", dependent: :destroy
  accepts_nested_attributes_for :attendees

  attr_accessor :status_complete


  scope :contextual, lambda { |context| where(context_type: context.class, context_id: context.id) }

  validates :title, presence: { message: "Title is required." }

  def update_calendar
    return unless user
    return false if status == "draft"

    failed = false
    result_id = nil

    event_status = status == "cancelled" ? "cancelled" : "confirmed"

    if user_calendar_entry_id.blank? && event_status != "cancelled"
      event_attendees = []
      attendees.each do |attendee|
        if !attendee.address.blank?
          status = "needsAction"
          status = "accepted" if attendee.user_id == user_id
          event_attendees << Google::Apis::CalendarV3::EventAttendee.new(
            email: attendee.address,
            display_name: attendee.display_name,
            response_status: status,
          )
        end
      end



      event = Google::Apis::CalendarV3::Event.new(
        summary: title,
        description: summary,
        location: location,
        start: Google::Apis::CalendarV3::EventDateTime.new(date_time: start_date.to_datetime.rfc3339),
        end: Google::Apis::CalendarV3::EventDateTime.new(date_time: end_date.to_datetime.rfc3339),
        status: event_status,
        time_zone: tenant.time_zone,
        attendees: event_attendees,
      )
      result_id = user.create_calendar_event("primary", event, send_updates: true)

    elsif user_calendar_entry_id.present?
      event = user.get_calendar_event("primary", user_calendar_entry_id)
      if event == "not_found"
        self.user_calendar_entry_id = nil
      elsif event
        event.summary = title
        event.description = summary
        event.location = location
        event.start = Google::Apis::CalendarV3::EventDateTime.new(date_time: start_date.to_datetime.rfc3339)
        event.end = Google::Apis::CalendarV3::EventDateTime.new(date_time: end_date.to_datetime.rfc3339)
        event.status = event_status
        time_zone = tenant.time_zone

        attendees.each do |attendee|
          found = false
          event.attendees.each do |event_attendee|
            found = true if attendee.address == event_attendee.email
          end
          if !found
            event.attendees << Google::Apis::CalendarV3::EventAttendee.new(
              email: attendee.address,
              display_name: attendee.display_name
            )
          end
        end

        event.attendees.reverse_each do |event_attendee|
          found = false
          attendees.each do |attendee|
            found = true if attendee.address == event_attendee.email
          end
          if !found
            event.attendees.delete(event_attendee)
          end
        end

        result_id = user.update_calendar_event("primary", user_calendar_entry_id, event, send_updates: true)
      end
    end

    if result_id == "failed"
      failed = true
    elsif result_id
      self.user_calendar_entry_id = result_id
    end
    self.calendar_needs_update = false unless failed
    save
  end

  def notify_creator(type="created")
    return unless user && status == "draft"
    mbe = Platform.is_mbe?(tenant)

    dest_address = user.email
    subject = I18n.t("platform.new_printspeak_meeting", mbe: mbe, title: title)
    subject = I18n.t("platform.updated_printspeak_meeting", mbe: mbe, title: title) if type == "update"
    subject = I18n.t("platform.upcoming_printspeak_meeting", mbe: mbe, title: title) if type == "reminder"
    subject = I18n.t("platform.cancelled_printspeak_meeting", mbe: mbe, title: title) if type == "cancelled"

    attendee_list = ""
    attendees.each do |attendee|
      attendee_list << "#{attendee.display_name} <#{attendee.address}>"
    end

    body = %Q{
      <p>Hi #{user.full_name},</p>
      <p>#{subject}</p>
      <table>
        <tr>
          <td width="150">#{I18n.t("title")}:</td>
          <td>#{title}</td>
        </tr>
        <tr>
          <td width="150">#{I18n.t("summary")}:</td>
          <td>#{summary}</td>
        </tr>
        <tr>
          <td width="150">#{I18n.t("location")}:</td>
          <td>#{location}</td>
        </tr>
        <tr>
          <td width="150">#{I18n.t("start_date")}:</td>
          <td>#{tenant.local_strftime(start_date, '%%DM-%%DM-%y %l:%M %p')}</td>
        </tr>
        <tr>
          <td width="150">#{I18n.t("end_date")}:</td>
          <td>#{tenant.local_strftime(end_date, '%%DM-%%DM-%y %l:%M %p')}</td>
        </tr>
        <tr>
          <td width="150">#{I18n.t("notes")}:</td>
          <td>#{note}</td>
        </tr>
        <tr>
          <td width="150">#{I18n.t("attendees")}:</td>
          <td>#{attendee_list}</td>
        </tr>
        <tr>
          <td width="150">#{I18n.t("link_url")}:</td>
          <td><a href="#{Rails.application.routes.url_helpers.url_for(controller: :meetings, action: :show, id: id)}">#{I18n.t("platform.view_in_printspeak", mbe: mbe)}</a></td>
        </tr>
      </table>
    }

    Email.ses_send([dest_address], subject, Email.printspeak_template(body))
  end
end
