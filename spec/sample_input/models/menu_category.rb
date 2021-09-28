class MenuCategory < ActiveRecord::Base
  belongs_to :shop
end

# menu_categories
#
# id                                       bigint
# shop_id                                  integer
# name                                     text
# position                                 integer
