# frozen_string_literal: true

class CountryState < ActiveRecord::Base
  belongs_to :country
  has_and_belongs_to_many :holidays
end
