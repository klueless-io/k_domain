class BackgroundJobResult < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :user

  def complete
    true
  end

  def self.clean_expired
    jobs_to_cleanup = BackgroundJobResult.where("expires_at IS NOT NULL AND expires_at < ?", Time.now).limit(10)
    jobs_to_cleanup.each do |job|
      BackgroundJob.cleanup(job)
      job.destroy
    end

    duplicate_results_query = %Q{
      SELECT *
      FROM background_job_results
      WHERE id IN (
        SELECT N.id
        FROM (
          SELECT id, ROW_NUMBER() OVER(PARTITION BY job_type, job_hash ORDER BY created_at DESC) AS row_num
          FROM background_job_results
        ) N
        WHERE N.row_num > 1
      )
    }

    duplicate_jobs = BackgroundJobResult.find_by_sql(duplicate_results_query)
    duplicate_jobs.each do |job|
      BackgroundJob.cleanup(job)
      job.destroy
    end
  end
end