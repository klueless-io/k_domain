# frozen_string_literal: true

class ApiLog < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :context, polymorphic: true
  belongs_to :user
end
