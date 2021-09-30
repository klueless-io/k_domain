# frozen_string_literal: true

class RegionConfig < ActiveRecord::Base
  def self.get_value(option, default=nil)
    result = nil
    begin
      result = RegionConfig.where(option: option).first.try(:value)
    rescue StandardError
    end
    result = default if result.nil?
    result
  end

  def self.require_value(option)
    result = RegionConfig.get_value(option)
    if result.nil?
      raise "Missing required region configuration option #{option}."
    end
    result
  end
end
