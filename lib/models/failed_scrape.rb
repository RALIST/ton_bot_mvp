class FailedScrape < ActiveRecord::Base
  validates :url, presence: true
  validates :source, presence: true
  
  scope :retryable, -> { where('retry_count < ? AND last_retry_at < ?', 3, 1.hour.ago) }
  scope :by_source, ->(source) { where(source: source) }
  
  def self.record_failure(url:, source:, error:)
    failed_scrape = find_or_initialize_by(url: url, source: source)
    failed_scrape.error = error
    failed_scrape.retry_count += 1
    failed_scrape.last_retry_at = Time.current
    failed_scrape.save
  end
  
  def mark_as_successful
    destroy
  end
end
