# frozen_string_literal: true

class AccountHistoryData < ActiveRecord::Base
  default_scope { where(deleted: false) }
  belongs_to :company
  belongs_to :tenant
end
