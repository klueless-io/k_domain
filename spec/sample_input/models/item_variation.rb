class ItemVariation < ActiveRecord::Base
  belongs_to :item
end

# item_variations
#
# id                                       bigint
# item_id                                  integer
# name                                     text
# default                                  boolean
# qty                                      integer
# qty_variation                            text
