class RawDocument < ActiveRecord::Base
  has_many :embeddings, foreign_key: 'document_id'
  
  validates :url, presence: true, uniqueness: true
  
  scope :processed, -> { where(processed: true) }
  scope :unprocessed, -> { where(processed: false) }
  
  def embedding_count
    embeddings.count
  end

  def self.store_from_scrape(url:, title:, content:, html_content:, section:, metadata:)
    create_or_update = find_or_initialize_by(url: url)
    create_or_update.assign_attributes(
      title: title,
      content: content,
      html_content: html_content,
      section: section,
      metadata: metadata,
      processed: false
    )
    create_or_update.save
    create_or_update
  end
  
  def mark_as_processed!
    update!(processed: true)
  end
  
  def self.ransackable_attributes(auth_object = nil)
    %w[id url title section processed created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    []
  end
end
