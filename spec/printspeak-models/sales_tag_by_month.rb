# frozen_string_literal: true

class SalesTagByMonth < ActiveRecord::Base
  extend RailsUpgrade

  default_scope {
    order(month_date: :desc)
  }

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?
end
