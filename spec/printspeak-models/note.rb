# frozen_string_literal: true

class Note < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :user
  belongs_to :context, polymorphic: true

  default_scope { where(deleted: false) }
  scope :contextual, lambda { |context| where(context_type: context.class, context_id: context.id) }

  validates :title, presence: { message: "Title is required." }
  validates :message, presence: { message: "Message is required." }

  def user
    User.unscoped.where(id: user_id).try(:first) unless user_id.nil?
  end
end
