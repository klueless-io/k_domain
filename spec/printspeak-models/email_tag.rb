# frozen_string_literal: true

class EmailTag < ActiveRecord::Base
  has_and_belongs_to_many :emails
end
