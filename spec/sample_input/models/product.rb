class Product < ActiveRecord::Base
  belongs_to :shop
end

# products
#
# id                                       bigint
# shop_id                                  integer
# title                                    text
# price                                    float
