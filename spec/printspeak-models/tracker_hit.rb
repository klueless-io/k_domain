# frozen_string_literal: true

class TrackerHit < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tracker, **belongs_to_required
  validates :tracker, presence: { message: "must exist" } if rails4?

  scope :no_unsub_links, -> { where("trackers.path NOT LIKE ?", "%unsubscribe%") }
end
