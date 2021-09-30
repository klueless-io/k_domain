class PendingAttachment < ActiveRecord::Base
  belongs_to :tenant
  before_destroy :cleanup_temporary_files



  def process_attachment
    extension_blacklist = [".exe", ".sh"]
    max_size = 1024*1024*200
    if !complete && !needs_asset.blank?
      file_contents = nil
      asset_type = needs_asset["type"]
      case asset_type
      when "statement"
        company_id = needs_asset["company_id"]
        invoices_only = needs_asset["invoices_only"] || false
        company = Company.where(id: company_id, tenant_id: tenant.id).first if !company_id.blank?
        if company
          account_statement = Utils::AccountStatement.new(tenant, company, invoices_only: invoices_only).generate
          if account_statement[:error].blank?
            self.warn = account_statement[:warn]
            self.file_name = "Statement_#{company.id}.pdf"
            self.file_name = "Invoices_#{company.id}.pdf" if invoices_only
            self.inline = false if account_statement[:pdf_content].length >= 20000000
            file_contents = account_statement[:pdf_content]
          else
            self.error = account_statement[:error]
          end
        else
          self.error = "company_not_found"
        end
      when "pdf"
        context_id = needs_asset["context_id"]
        context_type = needs_asset["context_type"]
        context = nil
        if !context_id.blank? && !context_type.blank?
          found_context = context_type.restricted_constantize(PrintSpeak::Application.config.common_context_types).where(id: context_id).first
          context = found_context if found_context && found_context.tenant_id == tenant.id
        end

        pdf_url = ""
        if context
          if context.try(:needs_pdf).nil?
            self.error = "no_pdf_for_context"
          else
            if context.needs_pdf
              klass = context.class
              klass = Invoice if [Sale, Order].include?(context.class)
              preferred_name = nil
              case klass
              when Invoice
                preferred_name = tenant.preferred_invoice_name
              when Estimate
                preferred_name = tenant.preferred_estimate_name
              end
              Utils::Pdf.new(tenant, klass, preferred_name).perform_single(context.id)
            end

            context.reload

            if context.needs_pdf == false
              pdf_url = Pdf.presigned_pdf(context)
              file_name = "#{context.invoice_number}.pdf"
              file_name = "#{context.platform_id}.pdf"  if file_name.blank?

              begin
                URI.parse(URI.encode(pdf_url, "[]"))
              rescue URI::InvalidURIError
                self.error = "invalid_url"
              end

              if error.blank?
                downloaded_file = nil
                begin
                  downloaded_file = HTTParty.get(pdf_url)
                  if downloaded_file.blank? || file_name.blank?
                    self.error = "invalid_file"
                  end
                rescue Exception => e
                  self.error = "could_not_fetch_pdf_url"
                end

                if error.blank?
                  self.file_name = file_name
                  self.inline = false if downloaded_file.size >= 20000000
                  file_contents = downloaded_file.parsed_response
                end
              end
            else
              self.error = "pdf_failed"
            end
          end
        else
          self.error = "invalid_context"
        end
      when "url"
        file_url = needs_asset["file_url"]
        if !file_url.blank?
          url = file_url
          file_name = needs_asset["file_name"]
          file_name = url.split("#").shift.split("?").shift.split("/").pop if file_name.blank?
          file_extension = File.extname(file_name)
          if extension_blacklist.include?(file_extension)
            self.error = "file_type_not_allowed"
          else
            begin
              URI.parse(URI.encode(url, "[]"))
            rescue URI::InvalidURIError
              self.error = "invalid_url"
            end

            if error.blank?
              downloaded_file = nil
              begin
                downloaded_file = HTTParty.get(url)
                if downloaded_file.blank? || file_name.blank?
                  self.error = "invalid_file"
                elsif downloaded_file.size > max_size
                  self.error = "file_exceeds_size"
                end
              rescue Exception => e
                self.error = "could_not_fetch_url"
              end

              if error.blank?
                self.file_name = file_name
                self.inline = false if downloaded_file.size >= 20000000
                file_contents = downloaded_file.parsed_response
              end
            end
          end
        else
          self.error = "invalid_url"
        end
      when "asset"
        attaching_asset_id = needs_asset["asset_id"]
        attaching_asset = Asset.where(tenant_id: tenant_id, id: attaching_asset_id).first if !attaching_asset_id.blank?
        if attaching_asset
          downloaded_file = HTTParty.get(URI.encode(attaching_asset.url, "[]"))
          if downloaded_file.blank?
            self.error = "could_not_fetch_asset"
          elsif downloaded_file.size > max_size
            self.error = "file_exceeds_size"
          else
            self.file_name = attaching_asset.file_name
            self.inline = false if downloaded_file.size >= 20000000
            file_contents = downloaded_file.parsed_response
          end
        else
          self.error = "invalid_asset"
        end
      when "job"
        invoice_id = needs_asset["invoice_id"]
        invoice = Invoice.where(id: invoice_id, tenant_id: tenant.id).first if !invoice_id.blank?
        if invoice
          downloaded_file = nil
          url = "#{tenant.report_url}/PrintSmith/reportservlet?invoiceTicket=EFI_jobTicket.rpt&reportParameter=#{invoice.platform_id}&showShippingCharges=false&showBarcode=true&ignoreSession=true"
          begin
            downloaded_file = HTTParty.get(url)
            if downloaded_file.blank?
              self.error = "job_ticket_invalid_file"
            elsif downloaded_file.size > max_size
              self.error = "file_exceeds_size"
            end
          rescue Exception => e
            self.error = "could_not_fetch_job"
          end

          if error.blank?
            self.file_name = "Job_Ticket_#{invoice.invoice_number}.pdf"
            self.inline = false if downloaded_file.size >= 20000000
            file_contents = downloaded_file.parsed_response
          end
        else
          self.error = "invoice_not_found"
        end
      when "waybill"
        shipment_id = needs_asset["shipment_id"]
        mbe = needs_asset["mbe"] || false
        shipment = Shipment.where(id: shipment_id, tenant_id: tenant.id).first if !shipment_id.blank?
        if shipment
          waybill = nil
          if mbe
            waybill = Mbe::Api.new(tenant).shipment.mbe_waybill(shipment.platform_id)
          else
            waybill = Mbe::Api.new(tenant).shipment.waybill(shipment.platform_id)
          end
          if waybill
            tracking = shipment.courier_tracking
            tracking = shipment.mbe_tracking if tracking.blank?
            self.file_name = "WAYBILL-#{tracking}.pdf"
            self.file_name = "MBE-WAYBILL-#{shipment.mbe_tracking}.pdf" if mbe
            self.inline = false if waybill.length >= 20000000
            file_contents = waybill
          else
            self.error = "waybill_could_not_fetch"
          end
        else
          self.error = "shipment_not_found"
        end
      else
        self.error = "request_unknown_asset_type"
      end

      if error.blank?
        if !file_contents.blank?
          asset = Asset.new(tenant_id: tenant.id,
                            enterprise_id: tenant.enterprise.id,
                            category: "Email Attachment",
                            new_file_contents: file_contents,
                            new_file_name: self.file_name,
                            context_type: "PendingAttachment",
                            context_id: id)
          if asset.save
            self.complete = true
          else
            asset = nil
            self.error = "failed"
          end
        else
          self.error = "empty_attachment"
        end
      end
    elsif complete
      asset = Asset.where(context_type: "PendingAttachment", context_id: id).first
      if !asset
        self.error = "missing_attachment"
      end
    else
      self.error = "request_invalid_asset"
    end

    save
  end

  def find_asset
    Asset.where(context_type: "PendingAttachment", context_id: id).first
  end

  def destroy_asset
    asset = find_asset
    asset.destroy if asset
  end

  def self.process_pending_attachments(tenant)
    pending_attachments = PendingAttachment.where(tenant: tenant, complete: false, error: nil).where("needs_asset IS NOT NULL AND needs_asset != ?" , "{}").order("bulk ASC NULLS FIRST, created_at ASC").limit(5)
    pending_attachments.each do |pending_attachment|
      pending_attachment.process_attachment
    end

    stale_attachments = PendingAttachment.where(tenant: tenant).where("created_at < ?", 1.day.ago)
    stale_attachments.each do |stale_attachment|
      stale_attachment.destroy_asset
      stale_attachment.destroy
    end

    stale_assets = Asset.where(tenant_id: tenant.id, context_type: "PendingAttachment").where("created_at < ?", 1.day.ago)
    stale_assets.each do |stale_asset|
      stale_asset.destroy
    end
  end

  private

  def cleanup_temporary_files
    begin
      File.delete(path) if !path.blank?
    rescue StandardError
    end
  end
end
