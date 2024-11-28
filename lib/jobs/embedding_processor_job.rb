require 'sidekiq'
require_relative '../embeddings'

module TonBot
  class EmbeddingProcessorJob
    include Sidekiq::Job

    sidekiq_options queue: :embeddings, retry: 3

    def perform(document_id)
      conn = PG.connect(
        host: ENV['DB_HOST'],
        port: ENV['DB_PORT'],
        dbname: ENV['DB_NAME'],
        user: ENV['DB_USER'],
        password: ENV['DB_PASSWORD']
      )

      # Fetch the raw document
      document = fetch_document(conn, document_id)
      return unless document

      # Process the document
      embeddings = TonBot::Embeddings.new
      chunks = embeddings.create_chunks(document['content'])
      
      chunks.each do |chunk|
        embedding = embeddings.generate_embedding(chunk)
        next unless embedding

        store_embedding(conn, embedding, chunk, document)
      end

      # Mark document as processed
      mark_as_processed(conn, document_id)
    rescue StandardError => e
      puts "Error processing document #{document_id}: #{e.message}"
      raise
    ensure
      conn&.close
    end

    private

    def fetch_document(conn, document_id)
      result = conn.exec_params('SELECT * FROM raw_documents WHERE id = $1', [document_id])
      result.first
    end

    def store_embedding(conn, embedding, chunk, document)
      metadata = JSON.parse(document['metadata'])
      
      sql = <<-SQL
        INSERT INTO embeddings (
          embedding,
          content,
          document_id,
          section,
          url,
          metadata
        ) VALUES ($1, $2, $3, $4, $5, $6)
      SQL

      conn.exec_params(
        sql,
        [
          embedding,
          chunk,
          document['id'],
          document['section'],
          document['url'],
          metadata.to_json
        ]
      )
    end

    def mark_as_processed(conn, document_id)
      conn.exec_params(
        'UPDATE raw_documents SET processed = true WHERE id = $1',
        [document_id]
      )
    end
  end
end
