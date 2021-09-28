# frozen_string_literal: true

class AppUser < ActiveRecord::Base
  belongs_to :asp_net_user
end

# app_users
#
# id                                       bigint
# user_id                                  text
# first_name                               text
# last_name                                text
# phone_number                             text
