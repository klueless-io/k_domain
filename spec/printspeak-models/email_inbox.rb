class EmailInbox < ActiveRecord::Base
  self.table_name = "inboxes"
  self.primary_key = "id"

  establish_connection "mail_#{Rails.env}".to_sym

  has_many :email_messages

  alias_attribute :messages, :email_messages

  def tenant_users(tenant)
    user_ids = []
    users.each do |user|
      user_ids << user["user_id"] if !user.nil? && user["tenant_id"] == tenant.id
    end
    User.unscoped.where(id: user_ids)
  end

  def self.enterprise_inboxes
    result = EmailInbox.none

    users = User.enterprise_users
    if users && users.count > 0
      query = %Q{
        SELECT id, address, users, users_array->>'user_id' AS user_id
        FROM inboxes, json_array_elements(users::json) users_array
        WHERE json_typeof(users::json) = 'array'
        AND users_array->>'user_id' IN (#{users.pluck(:id).map { |s| "'#{s}'" }.to_csv})
      }
      result = EmailInbox.find_by_sql(query)
    end

    result
  end

  def self.user_mapped_addresses
    EmailInbox.all.pluck(:address).compact.uniq
  end
end