class CampaignMessage < ActiveRecord::Base
  belongs_to :campaign
  belongs_to :contact
  has_and_belongs_to_many :trackers, -> { uniq }
  has_many :hits, through: :trackers

  scope :has_clicks, -> { where("EXISTS (SELECT null FROM campaign_messages_trackers INNER JOIN trackers ON trackers.id = campaign_messages_trackers.tracker_id INNER JOIN tracker_hits ON tracker_hits.tracker_id = trackers.id WHERE trackers.method != 0 AND trackers.path NOT LIKE '%unsubscribe%' AND campaign_messages_trackers.campaign_message_id = campaign_messages.id)") }

  def new_tracker(path, type = :url)
    tracker = Tracker.new_tracker(path, type)
    trackers << tracker
    tracker
  end

  def total_clicks
    ids = trackers.no_unsub_links.where.not(method: 0).pluck(:id)
    result = 0
    result = TrackerHit.where(tracker_id: ids).count if ids.count > 0
    result
  end

  def total_opens
    ids = trackers.where(method: 0).pluck(:id)
    result = 0
    result = TrackerHit.where(tracker_id: ids).count if ids.count > 0
    result
  end

  def generate_failed_activity
    if campaign.test != true
      aggregated_activity_attrs = {
        tenant_id: campaign.tenant_id,
        campaign_id: campaign.id,
        activity_for: "campaign_failed_aggregated",
      }
      aggregated_activity = Activity.find_or_initialize_by(aggregated_activity_attrs)
      aggregated_activity.source_created_at = Time.now
      aggregated_activity.save
    end
  end
end
