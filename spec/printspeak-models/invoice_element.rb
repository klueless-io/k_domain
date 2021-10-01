# frozen_string_literal: true

class InvoiceElement < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :invoice
  belongs_to :element, polymorphic: true
end
