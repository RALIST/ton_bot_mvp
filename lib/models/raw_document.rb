class RawDocument < ActiveRecord::Base
  validates :url, presence: true, uniqueness: true
  
  scope :processed, -> { where(processed: true) }
  scope :unprocessed, -> { where(processed: false) }
  
  def embedding_count
    Embedding.where(document_id: id).count
  end
  
  def self.ransackable_attributes(auth_object = nil)
    %w[id url title section processed created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    []
  end
end
