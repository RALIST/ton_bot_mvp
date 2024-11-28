require 'sidekiq'
require_relative '../embeddings'

module TonBot
  class EmbeddingProcessorJob
    include Sidekiq::Job

    sidekiq_options queue: :embeddings, retry: 3

    def perform(document_id)
      # Fetch the raw document using ActiveRecord
      document = RawDocument.find(document_id)
      return unless document

      # Process the document
      embeddings = TonBot::Embeddings.new
      chunks = embeddings.create_chunks(document.content)
      
      chunks.each do |chunk|
        embedding_vector = embeddings.generate_embedding(chunk)
        next unless embedding_vector

        Embedding.store_chunk(
          embedding_vector: embedding_vector,
          content: chunk,
          document: document
        )
      end

      # Mark document as processed
      document.mark_as_processed!
    rescue StandardError => e
      puts "Error processing document #{document_id}: #{e.message}"
      raise
    end
  end
end
