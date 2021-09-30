# frozen_string_literal: true

class Address < ActiveRecord::Base
  default_scope { where(deleted: false) }
  belongs_to :tenant
  belongs_to :company

  # geocoded_by :full_street_address
  # after_validation :geocode

  def full_street_address
    address = ""
    address += "#{street1.strip} " if street1.present?
    address += "#{street2.strip} " if street2.present?
    address += "#{street3.strip} " if street3.present?
    address += "#{city.strip} " if city.present?
    address += "#{state.strip} " if state.present?
    address += "#{zip.strip} " if zip.present?
    address += country if country.present?

    address
  end

  def full_street_address_display
    address = ""
    address += "#{street1.strip}, " if street1.present?
    address += "#{street2.strip}, " if street2.present?
    address += "#{city.strip}, " if city.present?
    address += "#{state.strip}, " if state.present?
    address += zip.strip if zip.present?

    address
  end

  def update_geo
    geocoder_coord = Geocoder.coordinates(full_street_address)
    if geocoder_coord.present? && !(geocoder_coord[0] == latitude && geocoder_coord[1] == longitude)
      self.latitude = geocoder_coord[0]
      self.longitude = geocoder_coord[1]
      save
    end
  end
end
