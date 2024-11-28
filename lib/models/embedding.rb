class Embedding < ActiveRecord::Base
  belongs_to :raw_document, foreign_key: 'document_id'
  
  validates :content, presence: true
  validates :embedding, presence: true
  
  def self.store_chunk(embedding_vector:, content:, document:)
    create!(
      embedding: embedding_vector,
      content: content,
      document_id: document.id,
      section: document.section,
      url: document.url,
      metadata: document.metadata
    )
  end
  
  def self.similarity_search(query_embedding, limit = 5)
    find_by_sql([<<-SQL, query_embedding, query_embedding, limit])
      SELECT 
        embeddings.*,
        1 - (embedding <=> ?) as similarity
      FROM embeddings
      ORDER BY embedding <=> ?
      LIMIT ?
    SQL
  end
  
  def self.ransackable_attributes(auth_object = nil)
    %w[id content section url created_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    ['raw_document']
  end
end
