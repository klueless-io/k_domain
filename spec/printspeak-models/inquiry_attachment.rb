# frozen_string_literal: true

class InquiryAttachment < ActiveRecord::Base
  belongs_to :inquiry
end
