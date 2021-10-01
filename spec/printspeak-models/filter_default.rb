# frozen_string_literal: true

class FilterDefault < ActiveRecord::Base
  belongs_to :user
  belongs_to :tenant
  belongs_to :context, polymorphic: true
  validates_uniqueness_of :user_id, scope: %i[context_type context_id]
end
