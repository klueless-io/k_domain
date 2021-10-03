# frozen_string_literal: true

class Shop < ActiveRecord::Base
  belongs_to :app_user
end

# shops
#
# id                                       bigint
# app_user_id                              integer
# name                                     text
# address                                  text
# longitude                                float
# latitude                                 float
