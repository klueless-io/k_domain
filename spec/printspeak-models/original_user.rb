# frozen_string_literal: true

class OriginalUser < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :user, **belongs_to_required
  validates :user, presence: { message: "must exist" } if rails4?
end
