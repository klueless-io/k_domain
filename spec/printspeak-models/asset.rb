class Asset < ActiveRecord::Base
  attr_accessor :file
  attr_accessor :new_file_contents
  attr_accessor :new_file_name

  before_save :upload_to_s3
  after_destroy :remove_from_s3

  belongs_to :enterprise
  belongs_to :tenant



  default_scope { where.not(file_hash: nil) }
  scope :by_tenant, -> (tenant) { where("assets.tenant_id = ? OR assets.global = true", tenant.id) }
  scope :by_enterprise, -> (enterprise) { where(enterprise_id: enterprise.nil? ? -1 : enterprise.id) }

  def url
    asset_prefix = RegionConfig.require_value("asset_url")
    URI.escape("#{asset_prefix}#{file_hash}_#{file_name}")
  end

  def size
    FastImage.size(url)
  end

  def tracked_url
    tracker = Tracker.where(id: tracker_id).first
    if tracker.nil?
     tracker = Tracker.new_tracker(url, :asset)
     self.tracker_id = tracker.id
     save
    end
    tracker.generated_url
  end

  def presigned_url(inline = true, expires_in = 86400)
    filename = URI.encode(file_name, "[]")
    disposition = "inline;filename=\"#{filename}\""
    disposition = "attachment;filename=\"#{filename}\"" unless inline
    signer = Aws::S3::Presigner.new(client: s3_client)
    bucket_info = Asset.split_bucket_info("#{RegionConfig.require_value('asset_bucket')}/#{file_hash}_#{file_name}")
    url = signer.presigned_url(:get_object, bucket: bucket_info[:bucket], key: bucket_info[:key], response_content_disposition: disposition, expires_in: expires_in)
    url
  end

  def meta_link(target_tenant = nil)
    result = nil

    if !meta_data["link"].blank?
      if target_tenant
        template_merger = TemplateMerger.new(target_tenant)
        link_url = template_merger.translated_body(meta_data["link"])
        begin
          uri = URI.parse(link_url)
          link_url = "http://#{link_url}" if uri.scheme.blank?
          uri = URI.parse(link_url)
          result = link_url
        rescue URI::InvalidURIError
        end
      else
        result = meta_data["link"]
      end
    end

    result
  end

  def self.split_bucket_info(full_bucket_path)
    split_bucket = full_bucket_path.split("/")
    {
      bucket: split_bucket.first,
      key: split_bucket.drop(1).join("/")
    }
  end

  private

  def s3_client
    credentials = Aws::Credentials.new(Rails.application.secrets.aws_access_key_id, Rails.application.secrets.aws_secret_access_key)
    Aws::S3::Client.new(credentials: credentials, region: RegionConfig.require_value("bucket_region"))
  end

  def upload_to_s3
    begin
      if new_file_contents
        remove_from_s3
        self.file_hash = Digest::MD5.hexdigest(new_file_contents)
        self.file_name = new_file_name
        self.content_type = MIME::Types.type_for(new_file_name).try(:first).try(:content_type)
        duplicate_assets = Asset.where(file_hash: file_hash, file_name: file_name)
        if duplicate_assets.count == 0
          bucket_info = Asset.split_bucket_info("#{RegionConfig.require_value('asset_bucket')}/#{file_hash}_#{file_name}")
          resp = s3_client.put_object(
            content_disposition: "inline; filename=#{file_name}",
            acl: "public-read",
            bucket: bucket_info[:bucket],
            key: bucket_info[:key],
            body: new_file_contents
          )
          if resp.successful?
            self.new_file_contents = nil
            self.new_file_name = nil
            true
          else
            false
          end
        end
      else
        return false if file_hash.blank?
      end
    rescue StandardError
      false
    end
  end

  def remove_from_s3
    if file_hash
      duplicate_assets = Asset.where(file_hash: file_hash, file_name: file_name).where.not(id: id)
      if duplicate_assets.count == 0
        client = s3_client
        bucket_info = Asset.split_bucket_info("#{RegionConfig.require_value('asset_bucket')}/#{file_hash}_#{file_name}")
        client.delete_object(bucket_info)
      end
    end
  end
end
