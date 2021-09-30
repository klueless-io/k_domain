# frozen_string_literal: true

class ProspectStatusVersion < ActiveRecord::Base
  default_scope { order(version_no: :asc) }

  enum status: { Live: 1, Draft: 2, Locked: 3 }

  belongs_to :lead_type
  has_many :prospect_statuses, dependent: :destroy
  has_one :prospect_status

  acts_as_list scope: :lead_type, column: "version_no"
end
