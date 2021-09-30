# frozen_string_literal: true

class PhoneCall < ActiveRecord::Base
  validates :subject, length: { maximum: 250 }

  belongs_to :phoneable, polymorphic: true
  belongs_to :tenant
  belongs_to :user
  belongs_to :contact
  has_many :activities, dependent: :destroy

  scope :contextual, lambda { |context| where(context_type: context.class, context_id: context.id) }

  def self.internationalize_phone_number(number)
    codes = {
      "us" => "1",
      "au" => "61",
      "ro" => "40"
    }
    country_code = codes[RegionConfig.get_value("region")]
    # country_code = '40' #force country code

    if country_code
      number = Phony.normalize(number, cc: country_code)
      # number = "#{country_code}#{number}" unless number.starts_with?(country_code)
    end

    number = Phony.normalize(number)
    Phony.format(number, spaces: "")
  end
end
