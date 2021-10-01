class User < ActiveRecord::Base
  acts_as_reader

  default_scope { where(deleted_at: nil) }

  require "google/apis/calendar_v3"

  attr_accessor :skip_username_validation
  attr_accessor :skip_password_validation
  attr_accessor :skip_admin_validation
  attr_accessor :update_from_primary
  attr_accessor :updated_roles
  attr_accessor :taken_by_ids

  before_save :ensure_parent
  after_save :sync

  validate :username_unique
  # validates :username, presence: true
  # validates_uniqueness_of :username, if: "username.present?", message: "This username has been taken.", unless: :skip_username_validation

  validates :password, length: { minimum: 8, message: "8+ characters" }, unless: :skip_password_validation
  validates_confirmation_of :password, message: "should match New Password", unless: :skip_password_validation

  validates :password, format: {with:   /((?:(?=.*\d)).*)/x, message: "1 digit" }, unless: :skip_password_validation
  validates :password, format: {with:   /((?:(?=.*[a-z])).*)/x, message: "1 lowercase letter" }, unless: :skip_password_validation
  validates :password, format: {with:   /((?:(?=.*[A-Z])).*)/x, message: "1 uppercase letter" }, unless: :skip_password_validation
  validates :password, format: {with:   /((?:(?=.*\W)).*)/x, message: "1 special character" }, unless: :skip_password_validation

  # These only validate during admin registration
  with_options({on: :admin}) do |for_admin|
    for_admin.validates :first_name, presence: { message: "First name required." }, unless: :skip_admin_validation
    for_admin.validates :last_name, presence: { message: "Last name required." }, unless: :skip_admin_validation
    for_admin.validates :username, presence: { message: "Cannot be blank." }, unless: :skip_admin_validation
    for_admin.validates :password, presence: { message: "Password is mandatory." }, unless: :skip_admin_validation
  end

  with_options({on: :sso}) do |for_sso|
    for_sso.validates :first_name, presence: { message: "First name required." }
    for_sso.validates :last_name, presence: { message: "Last name required." }
  end

  devise :database_authenticatable,
         :rememberable,
         :trackable,
         :timeoutable,
         :lockable

  belongs_to :enterprise, required: true
  validates :enterprise, presence: { message: "must exist" }
  belongs_to :tenant, required: true
  validates :tenant, presence: { message: "must exist" }

  has_one :token

  has_many :phone_calls
  has_many :emails
  has_many :activities
  has_many :taken_bys
  has_many :sales_reps
  has_many :target_results
  has_many :estimates, through: :taken_bys
  has_many :invoices, through: :taken_bys
  has_many :campaigns
  has_many :statistics
  has_many :shared_users, dependent: :destroy
  has_many :email_aliases, dependent: :destroy
  has_many :holidays
  has_many :notes
  has_many :adjustments,  foreign_key: "sales_rep_user_id", primary_key: "id"
  has_many :filter_defaults
  has_many :meetings

  validate do |user|
    user.errors[:base] << "Banner merge field missing in email signature" if !user.banner.nil? && !user.email_signature.include?("{{banner}}")
    begin
      Mail::Address.new("#{user.display_name} <test@test.com>").format
    rescue Mail::Field::ParseError
      user.errors[:base] << "Display name contains invalid characters"
    end
  end

  before_validation do
    self.banner_id = 0 if banner.nil?
    self.number = number.gsub(/[^0-9]/, "") if attribute_present?("number")
  end

  def username_unique
    matching_users = User.unscoped.where(username: actual_username).where.not(id: id).count
    if matching_users > 0
      errors.add(:username, "must be unique")
    end
  end

  def to_s
    full_name
  end

  def banner
    Asset.where(id: banner_id, enterprise_id: enterprise_id, category: "Banner").first
  end

  def email_signature_merged(target_tenant)
    return "" if email_signature.nil?
    banner_html = ""
    selected_banner = banner
    selected_banner = primary_tenant.banner if selected_banner.nil? && !primary_tenant.nil?
    selected_banner = enterprise.banner if selected_banner.nil?
    if selected_banner
      banner_link = selected_banner.meta_link(target_tenant)
      banner_html = %Q{<img src="#{selected_banner.url}" width="500" style="display:block;width:100%;max-width:500px" class="img-flag" />}
      if !banner_link.blank?
        banner_html = %Q{<a href="#{banner_link}">#{banner_html}</a>}
      end
    end
    email_signature.gsub("{{banner}}", banner_html)
  end

  def email_name
    display_name.blank? ? full_name : display_name
  end

  def full_name
    [first_name, last_name].compact.join(" ")
  end

  def tenants
    result = Tenant.none

    if is_super_user? || is_enterprise_user? || is_super_reader?
      result = enterprise.tenants
    else
      tenant_ids = User.where(enterprise: enterprise, parent_id: parent_id).pluck(:tenant_id)
      result = Tenant.where(enterprise: enterprise, id: tenant_ids) if tenant_ids.count > 0
    end

    result
  end

  def can_access_tenant?(tenant_id)
    tenants.exists?(tenant_id)
  end

  def can_access_reports?
    hide_reports.blank?
  end

  def can_view_business_plan?
    business_plan || is_super_user?
  end

  def users
    User.unscoped.where(parent_id: parent_id)
  end

  def username
    if is_primary? || id.nil?
      actual_username
    else
      primary.username
    end
  end

  def actual_username
    read_attribute(:username)
  end

  def is_sso?
    Platform.is_mbe?(tenant) && platform_id.present?
  end

  def is_primary?
    parent_id == id
  end

  def primary
    User.unscoped.where(id: parent_id).first
  end

  def primary_tenant
    if is_super_user? || is_enterprise_user? || is_super_reader?
      enterprise.default_tenant
    else
      primary.tenant
    end
  end

  def add_tenant(target_tenant)
    return nil if is_super_user? || is_enterprise_user? || is_super_reader? || target_tenant.enterprise_id != enterprise_id || !deleted_at.nil?

    user = User.unscoped.find_or_initialize_by(tenant_id: target_tenant.id, enterprise_id: target_tenant.enterprise.id, parent_id: id)
    if user.id.nil? || (user && !user.deleted_at.nil?)
      user.username = SecureRandom.hex
      user.update_from_primary = true
      user.skip_username_validation = true
      user.skip_password_validation = true
      user.skip_admin_validation = true
      user.deleted_at = nil
      if !user.save
        raise "Failed to save user! Parent ID #{id}"
      end
    end
    user
  end

  def remove_tenant(target_tenant)
    return if is_super_user? || is_enterprise_user? || is_super_reader? || target_tenant.enterprise_id != enterprise_id

    user = User.unscoped.where(tenant_id: target_tenant.id, parent_id: id).first
    if user
      if user.is_primary?
        new_primary_tenant = user.tenants.where.not(id: user.tenant_id).order("tenants.name ASC").first
        set_primary_tenant(new_primary_tenant)
      end
      user.destroy
    end
  end

  def set_primary_tenant(target_tenant)
    user = User.unscoped.where(tenant_id: target_tenant.id, parent_id: id).first
    if user && !user.is_primary?
      primary_user = primary
      user.username = primary_user.username
      primary_user.username = SecureRandom.hex
      user.skip_username_validation = true
      user.skip_password_validation = true
      user.skip_admin_validation = true
      primary_user.skip_password_validation = true
      primary_user.skip_admin_validation = true
      if !primary_user.save
        raise "Could not save primary user when setting primary tenant! User id #{primary_user.id}"
      end
      if !user.save
        raise "Could not save user when setting primary tenant! User id #{user.id}"
      end
      User.unscoped.where(parent_id: primary.id).update_all(parent_id: user.id)
    end
  end

  def email_inbox(target_tenant = nil)
    result = nil
    target_tenant = primary_tenant if target_tenant.nil?
    if id && target_tenant.id
      query = %Q{
        SELECT id, address, users
        FROM inboxes
        WHERE users @> '[{"user_id": #{id}, "tenant_id": #{target_tenant.id}}]'::jsonb;
      }
      result = EmailInbox.find_by_sql(query).first
    end
    result
  end

  def email
    return nil if Rails.env.test?
    return nil if id.blank?

    email_inbox.try(:address)
  end

  def email_remove(target_tenant = nil)
    target_tenant = primary_tenant if target_tenant.nil?
    if id && target_tenant.id
      Token.destroy_all(user_id: id)
      inbox = email_inbox(target_tenant)
      if !inbox.nil? && !inbox.users.nil?
        writeInbox = EmailInboxWrite.find(inbox.id)
        writeInbox.users.delete_if { |user_info| user_info["user_id"] == id && user_info["tenant_id"] == target_tenant.id }
        writeInbox.save
      end
      EmailCredential.destroy_all(user_id: id)
    end
    self.email_notifications = ""
    save
  end

  def tenant_email(target_tenant)
    result = nil

    if target_tenant.use_smtp
      creds = email_creds(target_tenant)
      result = creds.smtp_username if creds && !creds.smtp_username.blank?
    else
      if id
        result = email_inbox.try(:address) unless Rails.env.test?
      end
    end

    result
  end

  def is_user?
    role == "User" ? true : false
  end

  def is_admin?
    role == "Admin" || is_enterprise_user? ? true : false
  end

  def is_super_reader?
    role == "Super Reader" ? true : false
  end

  def is_enterprise_user?
    role == "Enterprise User" || is_super_user? || is_master_user? ? true : false
  end

  def is_super_user?
    role == "Super User" || is_master_user? ? true : false
  end

  def is_master_user?
    role == "Master User" ? true : false
  end

  def self.enterprise_users
    User.where(role: ["Master User", "Super User", "Enterprise User"])
  end

  def can_send_email?
    !hide && !is_super_user? && !is_enterprise_user? && !is_super_reader?
  end

  def can_become?(target_user)
    result = false
    if is_super_user? && !target_user.is_super_user?
      result = true
    elsif is_enterprise_user? && !target_user.is_super_user? && !target_user.is_enterprise_user? && (!primary_tenant.nil? && !target_user.primary_tenant.nil? && target_user.primary_tenant.enterprise_id == primary_tenant.enterprise_id)
      result = true
    end
    result
  end

  def becomable_users
    result = User.none

    becomable_roles = []
    becomable_roles += ["User", "Super Reader", "Admin"] if is_enterprise_user?
    becomable_roles += ["Enterprise User"] if is_super_user?

    result = enterprise.visible_users.where(role: becomable_roles) if becomable_roles.count > 0

    result
  end

  def is_valid_ip?(ip_address)
    return true if ip_whitelist.blank?
    valid_addresses = ip_whitelist.split(",").map(&:strip)
    valid_addresses.include?(ip_address)
  end

  def self.tenant_admin_settable_roles
    valid_roles.find_all { |role| role.to_s.match(/\Atenant_/) }
  end

  def calendar
    Calendar.where("? = ANY(user_ids)", id).first
  end

  def create_calendar_event(calendar_id, event, send_updates: nil)
    result_id = nil
    if token && !token.fresh_token.blank?
      calendar_service = Google::Apis::CalendarV3::CalendarService.new
      calendar_service.authorization = token.authorization
      begin
        event.color_id = task_calendar_color if Array(1..11).include?(task_calendar_color)
        response = calendar_service.insert_event(calendar_id, event, send_notifications: send_updates)
        result_id = response.id
      rescue StandardError
        result_id = "failed"
      end
    end
    result_id
  end

  def update_calendar_event(calendar_id, event_id, event, send_updates: nil)
    result_id = nil
    if token && !token.fresh_token.blank?
      calendar_service = Google::Apis::CalendarV3::CalendarService.new
      calendar_service.authorization = token.authorization
      begin
        event.color_id = task_calendar_color if Array(1..11).include?(task_calendar_color)
        response = calendar_service.patch_event(calendar_id, event_id, event, send_notifications: send_updates)
        result_id = response.id
      rescue Google::Apis::ClientError => e
        result_id = "failed"
        result_id = "not_found" if e.status_code == 404
      rescue StandardError
        result_id = "failed"
      end
    end
    result_id
  end

  def get_calendar_event(calendar_id, event_id)
    result = nil
    if token && !token.fresh_token.blank?
      calendar_service = Google::Apis::CalendarV3::CalendarService.new
      calendar_service.authorization = token.authorization
      begin
        result = calendar_service.get_event(calendar_id, event_id)
      rescue Google::Apis::ClientError => e
        if e.status_code == 404
          result = "not_found"
        end
      end
    end
    result
  end

  def delete_calendar_event(calendar_id, event_id, send_updates: nil)
    result = false
    if token && !token.fresh_token.blank?
      calendar_service = Google::Apis::CalendarV3::CalendarService.new
      calendar_service.authorization = token.authorization
      begin
        calendar_service.delete_event(calendar_id, event_id, send_notifications: send_updates)
        result = true
      rescue Google::Apis::ClientError
        result = true
      rescue StandardError
        CalendarEntryDeletion.find_or_create_by(user_id: id, calendar_ident: calendar_id, entry_ident: event_id, send_updates: send_updates)
      end
    end
    result
  end

  def shared_user_ids
    shared_users.pluck(:shared_id)
  end

  def shared_users=(new_shared_users)
    if new_shared_users.nil?
      shared_users.destroy_all
    else
      new_shared_users = new_shared_users.reject { |c| c.blank? }.map(&:to_i)
      shared_users.where.not(shared_id: new_shared_users).destroy_all
      old_shared_users = shared_users.where(shared_id: new_shared_users).pluck(:shared_id)
      new_shared_users.each do |new_shared_user|
        shared_users << SharedUser.create!(user_id: id, shared_id: new_shared_user) unless old_shared_users.include?(new_shared_user)
      end
    end
  end

  def email_ready?(target_tenant)
    result = false

    if target_tenant.use_smtp
      creds = email_creds(target_tenant)
      result = creds && !(creds.smtp_server.blank? || creds.smtp_username.blank? || creds.smtp_password.blank? || creds.smtp_port.nil?)
    else
      result = !token.blank?
    end

    result
  end

  def email_creds(target_tenant)
    result = EmailCredential.where(user_id: id, tenant_id: target_tenant.id, enterprise_id: target_tenant.enterprise_id).try(:first)

    result = EmailCredential.new if result.nil?

    result
  end

  def salestarget(type, target_name, tenant)
    Salestarget.where(target_type: type, name: target_name, tenant_id: tenant.id, user_id: nil)
    .joins("LEFT OUTER JOIN salestargets sta ON sta.tenant_id = salestargets.tenant_id AND sta.name = salestargets.name AND sta.target_type = salestargets.target_type AND sta.user_id = #{id}")
    .select("salestargets.*", "sta.amount as user_amount")
    .group("salestargets.id", "sta.id").first
  end

  private

  def ensure_parent
    if parent_id.nil?
      self.parent_id = id
    end
  end

  def sync
    if !parent_id.nil?
      source_user = self
      if update_from_primary
        source_user = primary
      end

      if source_user.nil?
        raise "No source user for sync! Parent ID #{id}"
      end

      User.unscoped.where(parent_id: parent_id).update_all(
        enterprise_id: source_user.enterprise_id,
        platform_id: source_user.platform_id,
        platform_data: source_user.platform_data,
        hide: source_user.hide,
        role: source_user.role,
        sso_onboarding: source_user.sso_onboarding,
        first_name: source_user.first_name,
        last_name: source_user.last_name,
        manual_email: source_user.manual_email,
        test_email: source_user.test_email,
        sms_test_number: source_user.sms_test_number,
        ip_whitelist: source_user.ip_whitelist,
        eula_accepted_at: source_user.eula_accepted_at,
        encrypted_password: source_user.encrypted_password
      )
    else
      update_column(:parent_id, id)
    end
  end
end
