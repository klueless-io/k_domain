# frozen_string_literal: true

class SavedReport < ActiveRecord::Base
  has_paper_trail

  belongs_to :tenant
  belongs_to :enterprise
end
