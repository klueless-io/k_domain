# frozen_string_literal: true

class EstimateElement < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :estimate
  belongs_to :element, polymorphic: true
end
