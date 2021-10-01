# frozen_string_literal: true

class Deployment < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :tenant, **belongs_to_required
  validates :tenant, presence: { message: "must exist" } if rails4?

  has_many :backups, primary_key: :tenant_id, foreign_key: :tenant_id

  def live_build
    Build.where(name: name, os: os).first
  end
end
