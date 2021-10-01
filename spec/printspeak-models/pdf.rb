class Pdf < ActiveRecord::Base
  # Ideally we don't want to need this
  def self.presigned_pdf_by_key(key, platform_id, inline: true, expires_in: 3600)
    context = Invoice.where(key: key, platform_id: platform_id).first
    context = Estimate.where(key: key, platform_id: platform_id).first if context.nil?
    Pdf.presigned_pdf(context, inline: inline, expires_in: expires_in)
  end

  def self.presigned_pdf(context, inline: true, expires_in: 3600)
    url = "#invalid"
    if !context.nil?
      credentials = Aws::Credentials.new(Rails.application.secrets.aws_access_key_id, Rails.application.secrets.aws_secret_access_key)
      s3_client = Aws::S3::Client.new(credentials: credentials, region: RegionConfig.require_value("bucket_region"))
      filename = context.invoice_number
      disposition = "inline;filename=\"#{filename}.pdf\""
      disposition = "attachment;filename=\"#{filename}.pdf\"" unless inline
      signer = Aws::S3::Presigner.new(client: s3_client)
      bucket_info = Asset.split_bucket_info("#{RegionConfig.require_value('pdf_bucket')}/#{context.key}/#{context.platform_id}.pdf")
      url = signer.presigned_url(:get_object, bucket: bucket_info[:bucket], key: bucket_info[:key], response_content_disposition: disposition, expires_in: expires_in)
    end
    url
  end

  def self.presigned_img(context, size: "large", page: 1, expires_in: 900)
    credentials = Aws::Credentials.new(Rails.application.secrets.aws_access_key_id, Rails.application.secrets.aws_secret_access_key)
    s3_client = Aws::S3::Client.new(credentials: credentials, region: RegionConfig.require_value("bucket_region"))
    signer = Aws::S3::Presigner.new(client: s3_client)
    image_name = "#{context.platform_id}-#{size}-#{page - 1}.jpg"
    bucket_info = Asset.split_bucket_info("#{RegionConfig.require_value('pdf_bucket')}/#{context.key}/#{image_name}")
    url = signer.presigned_url(:get_object, bucket: bucket_info[:bucket], key: bucket_info[:key], expires_in: expires_in)
    url
  end
end
