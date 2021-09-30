# frozen_string_literal: true

class InterestCategory < ActiveRecord::Base
  enum interest_type: {personal: 1, product: 2 }
  default_scope { order("LOWER(name) ASC") }

  belongs_to :enterprise
  has_many :interests, dependent: :destroy
end
