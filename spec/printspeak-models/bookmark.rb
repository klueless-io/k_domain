# frozen_string_literal: true

class Bookmark < ActiveRecord::Base
  belongs_to :user
  belongs_to :context, polymorphic: true
  validates_uniqueness_of :user_id, scope: %i[context_type context_id]

  scope :for_user, -> (user) { where(user_id: user.id) }
end
