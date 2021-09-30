# frozen_string_literal: true

class EmailStatus < ActiveRecord::Base
  enum status: %i[bounce complaint unsubscribe]
end
