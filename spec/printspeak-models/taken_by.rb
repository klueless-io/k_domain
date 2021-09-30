# frozen_string_literal: true

class TakenBy < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  belongs_to :user
  belongs_to :location
  has_many :estimates
  has_many :invoices

  scope :with_valid_state, -> { where("latest_context_date >= ? OR (latest_context_date IS NULL AND created_at >= ?)", 24.months.ago, 1.day.ago) }
end
