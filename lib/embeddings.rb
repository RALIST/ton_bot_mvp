require 'openai'
require 'json'

module TonBot
  class Embeddings
    CHUNK_SIZE = 512
    OVERLAP_SIZE = 50
    VECTOR_SIZE = 1536  # text-embedding-ada-002 dimension size

    def initialize
      @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    end

    def process_documents(documents)
      documents.each do |doc|
        chunks = create_chunks(doc[:content])
        chunks.each do |chunk|
          embedding = generate_embedding(chunk)
          next unless embedding

          Embedding.store_chunk(
            embedding_vector: embedding,
            content: chunk,
            document: doc
          )
        end
      end
    end

    def find_similar(query_embedding, limit = 5)
      Embedding.similarity_search(query_embedding, limit)
    rescue StandardError => e
      puts "Error in find_similar: #{e.message}"
      raise e
    end

    def generate_embedding(text)
      response = @client.embeddings(
        parameters: {
          model: 'text-embedding-ada-002',
          input: text
        }
      )

      embedding = response.dig('data', 0, 'embedding')
      return nil unless embedding

      "[#{embedding.join(',')}]"
    rescue StandardError => e
      puts "Error generating embedding: #{e.message}"
      puts e.response if e.respond_to?(:response)
      nil
    end

    def create_chunks(text)
      return [] if text.nil? || text.empty?

      words = text.split
      chunks = []
      
      # Start position for each chunk
      start_pos = 0
      
      while start_pos < words.length
        # Calculate end position for current chunk
        end_pos = [start_pos + CHUNK_SIZE, words.length].min
        
        # Create chunk from current window
        chunk = words[start_pos...end_pos].join(' ')
        chunks << chunk
        
        # Move start position forward, accounting for overlap
        # Ensure we make forward progress by moving at least 1 position
        start_pos += [CHUNK_SIZE - OVERLAP_SIZE, 1].max
      end

      chunks
    end
  end
end
