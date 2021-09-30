# frozen_string_literal: true

class HiddenLeadType < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :lead_type
end
