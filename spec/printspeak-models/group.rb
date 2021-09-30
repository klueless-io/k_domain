# frozen_string_literal: true

class Group < ActiveRecord::Base
  extend RailsUpgrade

  default_scope { order(name: :asc) }

  has_and_belongs_to_many :tenants

  belongs_to :enterprise, **belongs_to_required
  validates :enterprise, presence: { message: "must exist" } if rails4?
end
