# frozen_string_literal: true

class LeadSource < ActiveRecord::Base
  default_scope { order("LOWER(lead_sources.name) ASC") }

  belongs_to :enterprise
end
