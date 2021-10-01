# frozen_string_literal: true

class SalesSummaryPickup < ActiveRecord::Base
  extend RailsUpgrade

  default_scope { where(deleted: false) }

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?
end
