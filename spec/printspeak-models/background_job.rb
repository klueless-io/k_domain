class BackgroundJob < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :user



  def process
    lifespan = 1.day
    job_result = @@job_funcs[job_type].call(self)
    if job_result && !job_result[:lifespan].blank?
      lifespan = job_result[:lifespan]
    end

    BackgroundJobResult.create(
      tenant_id: tenant_id,
      user_id: user_id,
      job_hash: job_hash,
      job_type: job_type,
      name: name,
      description: description,
      status_view: status_view,
      completed_view: completed_view,
      data: data,
      result: job_result,
      expires_at: Time.now + lifespan
    )
    destroy
  end

  def position_in_queue
    result = 0

    if status == "queued"
      result = BackgroundJob.where(status: "queued").where("created_at < ?", created_at).count
    end

    result
  end

  def self.lookup(tenant, job_type, hash)
    job = BackgroundJob.where(
      tenant: tenant,
      job_type: job_type,
      job_hash: hash,
    ).order(created_at: :desc).first

    if !job
      job = BackgroundJobResult.where(
        tenant: tenant,
        job_type: job_type,
        job_hash: hash,
      ).order(created_at: :desc).first
    end

    job
  end

  def self.queue(tenant: nil, user: nil, job_type: "", hash: "", name: "", description: "", data: {}, status_view: "", completed_view: "")
    if tenant.blank? || user.blank? || job_type.blank?
      raise "Attempted to queue a background job with insufficient information."
    end

    if hash.blank?
      hash = Digest::MD5.hexdigest(data.to_json)
    end

    job = BackgroundJob.lookup(tenant, job_type, hash)

    if !job
      name = job_type.titleize if name.blank?
      description = "#{name} Job" if description.blank?
      job = BackgroundJob.create(
        tenant: tenant,
        user: user,
        job_type: job_type,
        job_hash: hash,
        name: name,
        description: description,
        status: "queued",
        status_view: status_view,
        completed_view: completed_view,
        data: data
      )
    end

    job
  end

  def self.register(job_type, job_func, cleanup_func=nil)
    @@job_funcs ||= {}
    @@job_cleanup_func ||= {}

    if @@job_funcs.key?("job_type")
      raise "Attempted to register the same job key twice"
    end

    @@job_funcs[job_type] = job_func
    @@job_cleanup_func[job_type] = cleanup_func
  end

  def self.cleanup(job)
    if @@job_cleanup_func && @@job_cleanup_func[job.job_type]
      @@job_cleanup_func[job.job_type].call(job)
    end
  end

  def self.process_pending_job
    queue_job_query = %Q{
      UPDATE background_jobs
      SET status = 'running'
      WHERE id = (
        SELECT id
        FROM background_jobs
        WHERE status = 'queued'
        ORDER BY created_at ASC
        LIMIT 1
        FOR UPDATE SKIP LOCKED
      )
      RETURNING id;
    }
    background_job_id = ActiveRecord::Base.connection.execute(queue_job_query).first.try(:[], "id")
    background_job = nil
    background_job = BackgroundJob.where(id: background_job_id).first if !background_job_id.nil?
    if background_job
      background_job.process
    end
  end
end
