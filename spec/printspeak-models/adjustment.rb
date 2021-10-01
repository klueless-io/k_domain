# frozen_string_literal: true

class Adjustment < ActiveRecord::Base
  default_scope { where(affect_sales: true, deleted: false, voided: false) }

  scope :for_dates, ->(start_date, end_date) { where(posted_date: start_date..end_date) }
  scope :non_closed_out, -> { where(accounting_month: nil) }

  belongs_to :invoice
  belongs_to :company
  belongs_to :tenant
  belongs_to :user, class_name: "User", foreign_key: "id", primary_key: "sales_rep_user_id"
  belongs_to :location, class_name: "Location", foreign_key: "id", primary_key: "location_user_id"
end
