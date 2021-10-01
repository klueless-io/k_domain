# frozen_string_literal: true

class ReportRow < ActiveRecord::Base
  belongs_to :report
  default_scope { order("position ASC") }
  acts_as_list scope: :report
end
