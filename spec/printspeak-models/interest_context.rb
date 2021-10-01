# frozen_string_literal: true

class InterestContext < ActiveRecord::Base
  belongs_to :interest
  belongs_to :context, polymorphic: true
  belongs_to :user
  belongs_to :tenant
end
