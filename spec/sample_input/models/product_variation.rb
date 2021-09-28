# frozen_string_literal: true

class ProductVariation < ActiveRecord::Base
  belongs_to :product
  belongs_to :item_variation
end

# product_variations
#
# id                                       bigint
# product_id                               integer
# item_variation_id                        integer
# active                                   boolean
# title                                    text
# price_offset                             float
