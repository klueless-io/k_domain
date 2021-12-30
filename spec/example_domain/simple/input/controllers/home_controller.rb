class HomeController < ApplicationController
  layout false, only: %i[result current result_mbe current_mbe ajax_test_example_ajax_call ytd ytd_mbe ytd_orders ytd_estimates ytd_shipments]

  def index
  end
  def current
  end
  def current_mbe
  end
  def result
  end
  def result_mbe
  end
  def eula
  end
  def ytd
  end
  def ytd_mbe
  end
  def ytd_shipments
  end
  def ytd_orders
  end
  def ytd_estimates
  end
  def rolling_12_month_win_ratio
  end
  def get_estimates_target_and_max_value
  end
  def process_quoter_data
  end
end