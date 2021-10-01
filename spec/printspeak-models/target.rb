# frozen_string_literal: true

class Target < ActiveRecord::Base
  enum klass: %i[estimate sale shipment deferred]
  # enum metric: [:total, :count]
  belongs_to :tenant
  belongs_to :location
  belongs_to :taken_by_user, class_name: "User", foreign_key: "id", primary_key: "taken_by_user_id"
  belongs_to :sales_rep_user, class_name: "User", foreign_key: "id", primary_key: "sales_rep_user_id"
end
