# frozen_string_literal: true

class Stats
  def initialize(tenant_id, start_date, end_date, current)
    @tenant_id  = Array(tenant_id).first
    @start_date = start_date
    @end_date   = end_date
    @current    = current
    # pass in dumb objects no need to know of external object structure
  end

  def including_companies
    includes(:company)
  end
end
