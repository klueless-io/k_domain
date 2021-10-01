class ClearbitQuota < ActiveRecord::Base
  def increment
    self.used += 1
    save
  end

  def remaining
    max - self.used
  end

  def reset(force = false)
    needs_reset = (Time.now > end_date) || force
    if needs_reset
      self.used = 0
      self.start_date = end_date
      self.end_date = end_date + 1.month
      save
    end
    needs_reset
  end

  def self.get_quota(klass)
    result = ClearbitQuota.where(klass: klass.to_s).first
    if result.nil?
      result = ClearbitQuota.create(klass: klass.to_s, start_date: Time.now, end_date: Time.now + 1.month)
    end
    result
  end
end
