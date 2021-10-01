class Holiday < ActiveRecord::Base
  default_scope {
      includes(:holiday_dates)
      .order("holiday_dates.date")
  }

  scope :visible, -> {
    includes(:hidden_holidays)
    .where(hidden_holidays: { holiday_id: nil })
  }
  scope :has_dates, -> {
    where.not(holiday_dates: { date: nil }) # SHOW ONLY HOLIDAYS THAT HAVE DATES
  }
  scope :by_tenant_all, -> (tenant) {
    where("holidays.global = ? OR holidays.tenant_id = ?", true, tenant.id)
  }

  scope :by_state, -> (state) {
    joins(:country_states).where("country_states.name = ?",  state)
  }


  # CHAIN SCOPE TENANT VISIBLE
  class << self
    def tenant(tenant)
      if tenant.enterprise.countries.first.present? &&  tenant.enterprise.countries.first.country_states.count > 0
        by_state(tenant.state).by_tenant_all(tenant).visible.has_dates
      else
        by_tenant_all(tenant).visible.has_dates
      end
    end
  end

  scope :by_month_year, -> (month, year) {
      where("extract(month from holiday_dates.date) = ?", month)
      .where("extract(year from holiday_dates.date) = ?", year)
  }
  scope :current_month, -> {
      where("extract(month from holiday_dates.date) = ?",  Date.today.month)
      .where("extract(year from holiday_dates.date) = ?",  Date.today.year)
  }

  scope :gone, -> (selected_date) { where("extract(day from holiday_dates.date) < ?", selected_date.day) }
  scope :left, -> (selected_date) { where("extract(day from holiday_dates.date) > ?", selected_date.day) }

  # RELATIONS
  has_many :holiday_dates, dependent: :destroy
  has_and_belongs_to_many :country_states
  has_many :hidden_holidays, dependent: :destroy
  belongs_to :tenant
  belongs_to :enterprise
  belongs_to :user



  # VALIDATIONS

  validates :name, presence: { message: "Holiday name is required." }
  validates :holiday_dates, presence: { message: "Holiday dates are required." }

  validate do
    validate_holiday_dates
  end

  # validate :validate_holiday_states

  def states
    Holiday.find(id).country_states
  end

  private

  def validate_holiday_dates
    date_format = Tenant.new.date_format(false)
    holiday_dates.each do |holiday|
      if holiday.date.blank?
        errors.add(:holiday_dates, "Date Format NOT VALID. Should be " + date_format)
        break
      end
    end
  end

  # def validate_holiday_states
  #   errors.add(:states, "Tenant State Error: Please update your tenant: Settings > Basic Information > State using Abbreviations: eg. AL") unless self.country_states.present?
  # end
end
