class SalesRep < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  # default_scope { where(deleted: false) }
  belongs_to :user
  belongs_to :location

  has_many :estimates
  has_many :invoices
  has_many :shipments

  def first_name
    name.split(" ")[0]
  end

  def send_change_sales_rep_email(host, current_user, context_name, leads)
    return unless try(:user).present?
    return unless Platform.is_printsmith?(self)

    email = try(:user).tenant_email(tenant)

    to_addrs = []
    to_addrs << test_mode_if_required(email) unless test_mode_if_required(email).blank?
    return unless to_addrs.count > 0

    if Platform.is_printsmith?(current_user)
      send_mail(host, self, current_user, leads, context_name, to_addrs, "Print Speak: New #{context_name} Lead Assignment from #{current_user.full_name}")
    end
  end

  def send_mail(host, sale_rep, current_user, leads, context_name, addresses, email_subject, source_email = "support@printspeak.com")
    Thread.new {
      Email.ses_send(
        addresses,
        email_subject,
        Emails::Salesrep.new.change_sales_rep(sale_rep, current_user, context_name, leads, tenant, host),
        source_email)
      ActiveRecord::Base.clear_active_connections!
    }
  end

  private

  def test_mode_if_required(email_address)
    if Rails.env.production?
      email_address
    else
      "emailtest@printspeak.com"
    end
  end
end
