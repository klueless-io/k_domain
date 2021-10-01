# frozen_string_literal: true

class EmailTemplateValue < ActiveRecord::Base
  belongs_to :email_template_field
  belongs_to :campaign, polymorphic: true
end
