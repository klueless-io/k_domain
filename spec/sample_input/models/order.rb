class Order < ActiveRecord::Base
  belongs_to :app_user
  belongs_to :shop
end

# orders
#
# id                                       bigint
# customer_id                              integer
# shop_id                                  integer
# order_details                            jsonb
# placed_at                                datetime
# in_queue_at                              datetime
# making_at                                datetime
# made_at                                  datetime
# cancelled_at                             datetime
# collected_at                             datetime
# fail_at                                  datetime
# fail_reason                              text
