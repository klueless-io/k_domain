# frozen_string_literal: true

class PortalComment < ActiveRecord::Base
  belongs_to :user
  belongs_to :context, polymorphic: true
  belongs_to :tenant

  def record_activity(contextual)
    return if !id
    return if !contextual

    activity_attrs = {
      tenant_id: contextual.tenant_id,
      portal_comment_id: id,
      activity_for: "portal_comment"
    }

    activity_attrs = Activity.add_contextual_attribute(activity_attrs, contextual)
    Activity.create!(activity_attrs)
  end

  def commenter_name
    return (name.blank? ? user.full_name : name) if user

    name.blank? ? "Customer" : name
  end
end
