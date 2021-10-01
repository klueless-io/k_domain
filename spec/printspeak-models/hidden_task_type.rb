# frozen_string_literal: true

class HiddenTaskType < ActiveRecord::Base
  belongs_to :task_type
end
