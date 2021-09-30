# frozen_string_literal: true

class Report < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tenant, **belongs_to_required
  belongs_to :user

  validates :tenant, presence: { message: "must exist" } if rails4?
  validates :name, presence: { message: "Report name cannot be empty!"}
  has_many :report_row, -> { order(position: :asc) }
end
