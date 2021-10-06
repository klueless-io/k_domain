# frozen_string_literal: true

class FavouriteOrder < ActiveRecord::Base
  belongs_to :app_user
  belongs_to :order
end

# favourite_orders
#
# id                                       bigint
# customer_id                              integer
# order_id                                 integer
