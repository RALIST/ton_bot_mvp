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
  
  def self.similarity_search(query_embedding, limit: 5, min_similarity: 0.7, section: nil)
    base_query = <<-SQL
      SELECT 
        embeddings.*,
        1 - (embedding <=> ?) as similarity
      FROM embeddings
      WHERE 1 - (embedding <=> ?) >= ?
    SQL

    if section.present?
      base_query += " AND section = ?"
      params = [query_embedding, query_embedding, min_similarity, section]
    else
      params = [query_embedding, query_embedding, min_similarity]
    end

    base_query += " ORDER BY similarity DESC LIMIT ?"
    params << limit

    find_by_sql([base_query, *params])
  end

  def self.hybrid_search(query_text:, query_embedding:, limit: 5)
    # Combine vector similarity with text similarity using ts_rank
    query = <<-SQL
      WITH vector_scores AS (
        SELECT 
          id,
          1 - (embedding <=> ?) as similarity
        FROM embeddings
      ),
      text_scores AS (
        SELECT 
          id,
          ts_rank(
            to_tsvector('english', content),
            plainto_tsquery('english', ?)
          ) as text_rank
        FROM embeddings
      )
      SELECT 
        e.*,
        (v.similarity * 0.7 + t.text_rank * 0.3) as combined_score
      FROM embeddings e
      JOIN vector_scores v ON e.id = v.id
      JOIN text_scores t ON e.id = t.id
      ORDER BY combined_score DESC
      LIMIT ?
    SQL

    find_by_sql([query, query_embedding, query_text, limit])
  end

  def self.contextual_search(query_embedding:, context_filter: {}, limit: 5)
    conditions = []
    params = [query_embedding]

    # Build conditions array and params array
    if context_filter[:has_code].present?
      conditions << "metadata->>'has_code' = ?"
      params << context_filter[:has_code].to_s
    end

    if context_filter[:section].present?
      conditions << "section = ?"
      params << context_filter[:section]
    end

    if context_filter[:subsection].present?
      conditions << "metadata->>'subsection' = ?"
      params << context_filter[:subsection]
    end

    # Construct the query
    query = <<-SQL
      SELECT 
        embeddings.*,
        1 - (embedding <=> ?) as similarity
      FROM embeddings
    SQL

    # Add WHERE clause only if there are conditions
    if conditions.any?
      query += " WHERE #{conditions.join(' AND ')}"
    end

    # Add ordering and limit
    query += " ORDER BY similarity DESC LIMIT ?"
    params << limit

    find_by_sql([query, *params])
  end
  
  def self.ransackable_attributes(auth_object = nil)
    %w[id content section url created_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    ['raw_document']
  end
end
