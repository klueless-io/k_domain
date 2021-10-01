# frozen_string_literal: true

class ProductionLocation < ActiveRecord::Base
  extend RailsUpgrade

  default_scope { where(deleted: false).order("orderby ASC NULLS LAST, name ASC") }

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  # belongs_to :estimate
  has_many :estimates, inverse_of: :production_location
  has_many :invoices, inverse_of: :production_location
end
