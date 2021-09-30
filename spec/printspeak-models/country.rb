# frozen_string_literal: true

class Country < ActiveRecord::Base
  has_many :country_states, dependent: :destroy
  has_and_belongs_to_many :enterprises
end
