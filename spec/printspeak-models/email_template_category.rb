# frozen_string_literal: true

class EmailTemplateCategory < ActiveRecord::Base
  enum categories: {inquiries: 9, shipments: 10, estimates: 1, orders: 2, sales: 3, campaigns: 5, contacts: 6, companies: 7, comments: 8}

  belongs_to :email_template

  def self.platform_categories(tenant)
    if Platform.is_printsmith?(tenant)
      EmailTemplateCategory.categories.reject { |k, v| k == "shipments" }
    elsif Platform.is_mbe?(tenant)
      EmailTemplateCategory.categories.reject { |k, v| %w[estimates orders].include?(k) }
    else
      EmailTemplateCategory.categories
    end
  end
end
