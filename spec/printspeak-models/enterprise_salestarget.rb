# frozen_string_literal: true

class EnterpriseSalestarget < ActiveRecord::Base
  belongs_to :enterprise
  belongs_to :lead_type
  belongs_to :prospect_status
end
