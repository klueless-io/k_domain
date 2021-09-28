# frozen_string_literal: true

class CustomerShop < ActiveRecord::Base
  belongs_to :app_user
  belongs_to :shop
end

# customer_shops
#
# id                                       bigint
# status                                   integer
# customer_id                              integer
# shop_id                                  integer
