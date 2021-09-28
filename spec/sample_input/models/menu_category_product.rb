# frozen_string_literal: true

class MenuCategoryProduct < ActiveRecord::Base
  belongs_to :menu_category
  belongs_to :product
end

# menu_category_products
#
# id                                       bigint
# menu_category_id                         integer
# product_id                               integer
# position                                 integer
