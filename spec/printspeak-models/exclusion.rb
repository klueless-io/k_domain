# frozen_string_literal: true

class Exclusion < ActiveRecord::Base
  belongs_to :user
  belongs_to :context, polymorphic: true
  validates_uniqueness_of :user_id, scope: %i[context_type context_id]

  scope :for_user, -> (user) { where(user_id: (user.is_a? Integer) ? user : user.id) }
  singleton_class.send(:alias_method, :by, :for_user)
end
