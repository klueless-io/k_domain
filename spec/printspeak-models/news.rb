# frozen_string_literal: true

class News < ActiveRecord::Base
  acts_as_readable on: :created_at
  belongs_to :enterprise

  scope :by_enterprise, -> (enterprise_id) { where("enterprise_id = ? or global IS TRUE", enterprise_id) }
end
