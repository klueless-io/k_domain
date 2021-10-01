class Task < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper

  acts_as_readable on: :created_at
  acts_as_commentable

  belongs_to :user, -> { unscope(where: :deleted_at) }
  belongs_to :tenant
  has_one :assigned_user, -> { unscope(where: :deleted_at) }, class_name: "User", foreign_key: "id", primary_key: "assigned_user_id"
  has_many :activities, dependent: :destroy
  belongs_to :taskable, polymorphic: true
  belongs_to :task_type
  belongs_to :task_repeat

  has_many :comments, as: :commentable

  validates :name, presence: { message: "Task name is required." }
  validates :assigned_user_id, presence: { message: "Please add a user." }
  validates :end_date, presence: { message: "Due date is required." }
  validates :start_date, presence: { message: "Start date is required." }

  def related_activities
    if taskable.class == Estimate
      Activity.where("activities.task_id = ? OR (activities.estimate_id = ? AND activities.task_id IS NULL)", id, taskable.id)
              .joins("LEFT OUTER JOIN emails ON activities.email_id = emails.id")
              .select("activities.*", "emails.from as email_from", "emails.to as email_to", "emails.subject as email_subject")
              .limit(20)
    elsif taskable.class == Order
      Activity.where("activities.task_id = ? OR (activities.invoice_id = ? AND activities.task_id IS NULL)", id, taskable.id)
              .joins("LEFT OUTER JOIN emails ON activities.email_id = emails.id")
              .select("activities.*", "emails.from as email_from", "emails.to as email_to", "emails.subject as email_subject")
              .limit(20)
    else
      activities.limit(20)
    end
  end

  def send_new_task_email(host)
    return unless not_a_self_assigned_task
    return unless assigned_user.tenant_email(tenant) != ""

    to_addrs = []
    to_addrs << test_mode_if_required(assigned_user.tenant_email(tenant)) unless test_mode_if_required(assigned_user.tenant_email(tenant)).blank?

    to_addrs = add_emails_from_notifications(to_addrs)

    return unless to_addrs.count > 0

    send_mail(host, to_addrs, "Print Speak: New Task Assignment ##{id} #{mode}: #{name} from #{user.full_name}")
  end

  def send_task_assignement_change_email(host, changing_user = nil)
    return unless not_a_self_assigned_task

    to_addrs = []
    to_addrs << test_mode_if_required(assigned_user.tenant_email(tenant)) if !assigned_user.nil? && !test_mode_if_required(assigned_user.tenant_email(tenant)).blank? && !(!changing_user.nil? && changing_user.id == assigned_user.id)
    to_addrs << test_mode_if_required(user.tenant_email(tenant)) unless test_mode_if_required(user.tenant_email(tenant)).blank?

    to_addrs = add_emails_from_notifications(to_addrs)

    return unless to_addrs.count > 0

    if changed?
      if changed.include?("assigned_user_id")
        send_mail(host, to_addrs, "Print Speak: Task Assignment change ##{id} #{mode}: #{name} #{assigned_user}")
      end
    end
  end

  def send_task_status_change_email(host, changing_user = nil)
    return unless not_a_self_assigned_task

    to_addrs = []
    to_addrs << test_mode_if_required(assigned_user.tenant_email(tenant)) if !assigned_user.nil? && !test_mode_if_required(assigned_user.tenant_email(tenant)).blank? && !(!changing_user.nil? && changing_user.id == assigned_user.id)
    to_addrs << test_mode_if_required(user.tenant_email(tenant)) unless test_mode_if_required(user.tenant_email(tenant)).blank?

    to_addrs = add_emails_from_notifications(to_addrs)

    return unless to_addrs.count > 0

    if changed?
      if changed.include?("status")
        send_mail(host, to_addrs, "Print Speak: Task Status ##{id} #{mode}: #{name} #{status}")
      end
    end
  end

  def send_task_update_email(host)
    to_addrs = []
    to_addrs << test_mode_if_required(assigned_user.tenant_email(tenant)) if !assigned_user.nil? && !test_mode_if_required(assigned_user.tenant_email(tenant)).blank?
    to_addrs << test_mode_if_required(user.tenant_email(tenant)) unless test_mode_if_required(user.tenant_email(tenant)).blank?

    to_addrs = add_emails_from_notifications(to_addrs)

    to_addrs = to_addrs.uniq

    return unless to_addrs.count > 0

    send_mail(host, to_addrs, "Print Speak: Task Update ##{id} #{mode}: #{name}")
  end

  def update_calendar(from_gcal = nil)
    if add_to_calendar && calendar_needs_update
      require "google/apis/calendar_v3"

      context = ""
      summary = "Task"
      assets_string = ""

      summary += " [#{task_type.name}]" if task_type.try(:name)
      summary += ": #{name.truncate(100)}"

      assets_count = Asset.where(context_id: id, context_type: self.class).count
      assets_string = "<br/>Attachments: #{assets_count} File#{ assets_count > 1 ? 's' : ''  }" if assets_count > 0

      event_status = status == "Cancelled" ? "cancelled" : "confirmed"

      event_start = Google::Apis::CalendarV3::EventDateTime.new(date_time: end_date.to_datetime.rfc3339)
      event_end = Google::Apis::CalendarV3::EventDateTime.new(date_time: (end_date.to_datetime + 15.minutes).rfc3339)

      # GET CONTEXT STRING
      if try(:taskable).present? && from_gcal.blank?
        domain = RegionConfig.require_value("domain")
        context = "<br/><br/>"
        context += " <strong>#{taskable.class}</strong>: <a href='https://#{domain}/#{taskable.class.to_s.downcase.pluralize }/#{taskable.id}'>"
        context += "##{taskable.try(:invoice_number)} " if taskable.try(:invoice_number)
        context += "#{taskable.try(:name)}</a>"
        context += " [#{ number_to_currency(taskable.try(:grand_total) || 0, precision: 2)}]" if  taskable.try(:grand_total)
        context += "<br/>"
        context += assets_string
      end

      task_description = description
      task_description = "" unless task_description.present?

      event = Google::Apis::CalendarV3::Event.new(
        summary: summary,
        description: task_description + context,
        start: event_start,
        end: event_end,
        status: event_status
      )

      failed = false
      result_id = nil
      if user_calendar_entry_id.blank?
        result_id = user.create_calendar_event("primary", event)
      else
        result_id = user.update_calendar_event("primary", user_calendar_entry_id, event)
      end

      if result_id == "failed"
        failed = true
      elsif result_id == "not_found"
        failed = true
        self.user_calendar_entry_id = nil
      elsif result_id
        self.user_calendar_entry_id = result_id
      end

      if !assigned_user.nil? && user.id != assigned_user.id
        result_id = nil
        if assigned_user_calendar_entry_id.blank?
          result_id = assigned_user.create_calendar_event("primary", event)
        else
          result_id = assigned_user.update_calendar_event("primary", assigned_user_calendar_entry_id, event)
        end

        if result_id == "failed"
          failed = true
        elsif result_id == "not_found"
          failed = true
          self.assigned_user_calendar_entry_id = nil
        elsif result_id
          self.assigned_user_calendar_entry_id = result_id
        end
      end

      self.calendar_needs_update = false unless failed
      save
    end
  end

  def send_mail(host, addresses, email_subject, source_email = "support@printspeak.com")
    Thread.new {
      Email.ses_send(addresses, email_subject, Emails::Task.new.new_task(self, tenant, host), source_email)
      ActiveRecord::Base.clear_active_connections!
    }
  end

  def send_task_due_email(host)
    if assigned_user.try(:email)
      dest_address = assigned_user.email
      email_subject = "Print Speak: Task DUE ##{id} #{mode}: #{name} from #{user.full_name}"
      email_body = Emails::Task.new.due_task_today(self, tenant, host)

      Email.ses_send([dest_address], email_subject, email_body)
    end
  end

  private

  def test_mode_if_required(email_address)
    if Rails.env.production?
      email_address
    else
      "emailtest@printspeak.com"
    end
  end

  def not_a_self_assigned_task
    !assigned_user.nil? && user.id != assigned_user.id
  end

  def add_emails_from_notifications(to_addrs)
    tenant.visible_users.where(id: notification_ids).each do |notification_user|
      to_addrs << test_mode_if_required(notification_user.email) unless notification_user.email.blank?
    end

    to_addrs
  end
end
