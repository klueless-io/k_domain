class Shop < ActiveRecord::Base
  belongs_to :app_user, a: 1, b: 3, fuckit: 'xxxx', ff: ' # ', c: 4, d: 33 # asdfklasj # abc
end

# shops
#
# id                                       bigint
# app_user_id                              integer
# name                                     text
# address                                  text
# longitude                                float
# latitude                                 float
