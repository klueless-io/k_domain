# frozen_string_literal: true

class CompanyMetric < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :company
end
