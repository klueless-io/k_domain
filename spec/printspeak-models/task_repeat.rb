# frozen_string_literal: true

class TaskRepeat < ActiveRecord::Base
  belongs_to :task
  validates_uniqueness_of :task_id
end
