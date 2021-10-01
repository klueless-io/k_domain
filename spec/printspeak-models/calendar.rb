# frozen_string_literal: true

class Calendar < ActiveRecord::Base
  belongs_to :user, required: true
  validates :user, presence: { message: "must exist" }

  has_many :calendar_entries
end
