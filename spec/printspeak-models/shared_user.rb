# frozen_string_literal: true

class SharedUser < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :user, **belongs_to_required
  validates :user, presence: { message: "must exist" } if rails4?

  belongs_to :shared, class_name: "User", foreign_key: :shared_id, **belongs_to_required
  validates :shared, presence: { message: "must exist" } if rails4?
end
