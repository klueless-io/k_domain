# frozen_string_literal: true

class ActionLog < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :user
  belongs_to :context, polymorphic: true

  validates :tenant_id, presence: true
  validates :action, presence: true
end
