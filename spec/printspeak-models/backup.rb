# frozen_string_literal: true

class Backup < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tenant, inverse_of: :backups, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?
end
