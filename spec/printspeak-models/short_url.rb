class ShortUrl < ActiveRecord::Base
  validates_presence_of :url
  # validates :url, format: URI::regexp(%w[http https])
  validates_uniqueness_of :slug
  validates_length_of :slug, within: 3..255, on: :create, message: "too long"

  # auto slug generation
  before_validation :generate_slug

  def generate_slug
    self.slug = SecureRandom.uuid[0..5] if slug.nil? || slug.empty?
    true
  end

  # fast access to the shortened link
  def short
    env_letter = RegionConfig.get_value("region")[0, 1]
    env_letter = "s" if Rails.env.staging?
    "https://#{env_letter}.pspk.io/u/" + slug + " "
  end

  # the API
  def self.shorten(url, slug = "")
    link = ShortUrl.where(url: url, slug: slug).first

    return link.short if link

    link = ShortUrl.new(url: url, slug: slug)
    return link.short if link.save

    ShortUrl.shorten(url, slug + SecureRandom.uuid[0..2])
  end
end