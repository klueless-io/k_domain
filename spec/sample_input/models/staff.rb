# frozen_string_literal: true

class Staff < ActiveRecord::Base
  belongs_to :shop
  belongs_to :app_user
end

# staffs
#
# id                                       bigint
# shop_id                                  integer
# user_id                                  integer
# type                                     text
