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

module DeIdentifiable
  def deidentifiable(*_p, **_o); end
end

class Company < ActiveRecord::Base
  extend DeIdentifiable
end
class Estimate < ActiveRecord::Base
  extend DeIdentifiable
end
class Invoice < ActiveRecord::Base
  extend DeIdentifiable
end
class Address < ActiveRecord::Base
  extend DeIdentifiable
end
class Contact < ActiveRecord::Base
  extend DeIdentifiable
end

class Thread
  def initialize(*_p, **_o, &block); end
end

class ApplicationRecord < ActiveRecord::Base
end

class Email < ActiveRecord::Base
  def self.ses_send(*_p, **_o); end
end

module Emails
  class Task
    def new_task(*_p, **_o); end
  end
  class Salesrep
    def change_sales_rep(*_p, **_o); end
  end
end

module EstimateConvertable; end
module ApiLoggable; end
module Excludable; end
module Bookmarkable; end
module Categorizable; end
module PgSearch
  module Model
  end
end
module Excludable; end
module JsonbStore
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def jsonb_store(*_p, **_o); end
  end
end
module ActionView
  module Helpers
    module NumberHelper
    end
  end
end
module PrintSpeak
  class Application
    def self.google_oath_secret_key
      'ABC'
    end
  end
end
class RegionConfig < ActiveRecord::Base
  def self.require_value(*_p, **_o, &block)
    'ABC'
  end
  def self.get_value
    return 'ABC'
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
