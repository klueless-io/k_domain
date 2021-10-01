# frozen_string_literal: true

class Proof < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :user
  belongs_to :invoice

  # CREATE INDEX CONCURRENTLY index_invoices_portal_key ON invoices (id ASC, portal_key, voided, deleted) WHERE (voided = FALSE OR voided IS NULL) AND deleted = FALSE

  def asset
    Asset.where(
      tenant_id: tenant_id,
      category: "Proof",
      context_type: "Proof",
      context_id: id,
    ).first
  end

  def revision_proofs
    Proof.where(
      tenant_id: tenant_id,
      invoice_id: invoice_id,
      revision_of_id: id
    ).order(created_at: :desc)
  end

  def latest_revision
    revision = Proof.where(tenant_id: tenant_id,
                           invoice_id: invoice_id,
                           revision_of_id: id,
                           approval_status: nil
                          ).order(number: :desc).first
    revision.nil? ? self : revision
  end

  def self.allowed_extensions
    %w[pdf jpg jpeg png]
  end

  def display_status
    result = ""
    case approval_status
    when "approved"
      result = "Approved"
    when "revise"
      result = "Changes Required"
    when "pending"
      result = "Awaiting Review"
    end
    result
  end
end
