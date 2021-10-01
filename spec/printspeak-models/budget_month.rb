class BudgetMonth < ActiveRecord::Base
  extend RailsUpgrade

  belongs_to :budget, **belongs_to_required
  validates :budget, presence: { message: "must exist" } if rails4?

  def dom_id(prefix = nil)
    prefix ||= "new" unless id
    [ prefix, self.class.name.underscore.gsub("/", "_"), id ].compact * "_"
  end
end
