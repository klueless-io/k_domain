# frozen_string_literal: true

class HiddenEmailTemplate < ActiveRecord::Base
  belongs_to :email_template
  belongs_to :tenant
end
