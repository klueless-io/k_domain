# frozen_string_literal: true

class NextActivity < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :contact
  belongs_to :context, polymorphic: true

  scope :active, -> {
    where(status: "active")
  }
end
