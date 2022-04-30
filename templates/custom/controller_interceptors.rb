class Rails
  def self.env; end

  def self.application
    OpenStruct.new(
      secrets: OpenStruct.new(
        credentials_secret_key: Base64.encode64('ABC'),
        aws_secret_access_key: Base64.encode64('ABC')
      )
    )
  end
end
class ApplicationController < ActionController::Base
  def self.require(*_p, **_o); end
end

module Admin
  class BaseController < ActionController::Base
  end
end
module Api
  module V1
    class BaseController < ActionController::Base
    end
  end
end

module Enterprises
  class BaseController < ActionController::Base
  end
end

module Portal
  class BaseController < ApplicationController
  end
end
module ActiveRecord
  class RecordNotFound
  end
end
class RegionConfig < ActiveRecord::Base
  def self.require_value(*_p, **_o, &block); end
end
module Aws
  class Credentials
    def initialize(*_p, **_o, &block); end
  end
  module S3
    class Client
      def initialize(*_p, **_o, &block); end
    end
  end
end

module Devise
  class SessionsController < ActionController::Base
  end
  class Mapping
    def self.find_scope!(*_p, **_o); end
  end
end

module Respondable; end
module ContactUpdateable; end
module SalesRepUpdateable; end
module MIME; end
module MaterialIconsHelper; end
module LocationUpdateable; end
module WantedByUpdateable; end
module FollowUpUpdateable; end
module EstimateArchiveUpdateable; end
module ContextContactUpdateable; end
module ProofDateUpdateable; end
module PoUpdateable; end
module SalesRepUpdateable; end
