# frozen_string_literal: true

class Tracker < ActiveRecord::Base
  enum method: %i[image url asset]

  has_and_belongs_to_many :campaign_messages, -> { uniq }
  has_and_belongs_to_many :emails, -> { uniq }
  has_many :hits, class_name: "TrackerHit", dependent: :destroy

  scope :no_unsub_links, -> { where("trackers.path NOT LIKE ?", "%unsubscribe%") }

  def self.new_tracker(path, type = :url)
    uuid = Base64.urlsafe_encode64(SecureRandom.uuid)
    Tracker.create(uuid: uuid, method: type, path: path)
  end

  def generated_url
    "#{PrintSpeak::Application.root_url}tracker/#{uuid}"
  end

  def hit(user_agent, referer, browser = nil)
    browser = Browser.new("") if browser.nil?
    hits.build(user_agent: user_agent, referer: referer, bot: browser.bot?, browser_modern: browser.modern?, browser: browser.name, device: browser.device.name, platform: browser.platform.name)
    save
  end

  def self.unsubscribe_url(url_id)
    "#{PrintSpeak::Application.root_url}email_unsubscribe/#{url_id}"
  end

  def self.view_email_url(url_id)
    "#{PrintSpeak::Application.root_url}email_view/#{url_id}"
  end
end
