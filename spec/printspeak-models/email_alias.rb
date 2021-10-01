# frozen_string_literal: true

class EmailAlias < ActiveRecord::Base
  belongs_to :user
  validates_uniqueness_of :email, scope: :user_id
  validate :check_email_valid

  def check_email_valid
    if !Email.valid_format?(email)
      errors.add(:email, :invalid)
    end
  end
end
