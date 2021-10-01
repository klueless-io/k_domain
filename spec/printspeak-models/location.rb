# frozen_string_literal: true

class Location < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tenant, inverse_of: :backups, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  belongs_to :identity

  has_many :statistics
  has_many :sales_reps
  has_many :adjustments, foreign_key: "location_user_id", primary_key: "id"

  validates :name, presence: true

  def to_s
    name
  end
end
