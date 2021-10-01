# frozen_string_literal: true

class EnterpriseTogglefield < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :enterprise, **belongs_to_required
  validates :enterprise, presence: { message: "must exist" } if rails4?
end
