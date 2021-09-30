# frozen_string_literal: true

class Sale < Invoice
  include Excludable
  include Bookmarkable
  include Categorizable
  include ApiLoggable

  self.table_name = "invoices"

  # belongs_to :sales_rep, :class_name => "SalesRep", :foreign_key => "user_id", :primary_key => "sales_rep_user_id"

  has_many :actions, as: :actionable
  has_many :orders, foreign_key: "sale_id"

  # has_many :activities
  belongs_to :contact

  default_scope { where.not(pickup_date: nil).where(voided: false, deleted: false) }

  scope :for_dates, ->(start_date, end_date) { where(pickup_date: start_date..end_date) }
  scope :non_closed_out, -> { where(accounting_month: nil) }
end
