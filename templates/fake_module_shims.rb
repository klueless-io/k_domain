class Rails
  def self.env; end

  def self.application
    OpenStruct.new(secrets: OpenStruct.new(credentials_secret_key: Base64.encode64('ABC')))
  end
end

module ActsAsCommentable
  module Comment
  end
end

module Scopes
  module CompanyScopes
  end
end

module ActionView
  module Helpers
    module NumberHelper
    end
  end
end

module RailsUpgrade
  def rails4?
    true
  end

  def rails5?
    true
  end

  def rails6?
    true
  end

  def belongs_to_required
    {}
  end
end
