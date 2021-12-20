# frozen_string_literal: true

class CustomerShop < ActiveRecord::Base
  belongs_to :customer, class_name: 'AppUser'
  belongs_to :shop
end

# customer_shops
#
# id                                       bigint
# status                                   integer
# customer_id                              integer
# shop_id                                  integer
