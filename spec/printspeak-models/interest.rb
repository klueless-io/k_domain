# frozen_string_literal: true

class Interest < ActiveRecord::Base
  belongs_to :interest_category
  belongs_to :user
  default_scope { order("LOWER(name) ASC") }
end
