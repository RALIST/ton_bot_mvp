require 'pg'
require 'pgvector'
require 'openai'
require 'json'

module TonBot
  class Embeddings
    CHUNK_SIZE = 512
    OVERLAP_SIZE = 50
    VECTOR_SIZE = 1536  # text-embedding-ada-002 dimension size

    def initialize
      @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
      @conn = PG.connect(
        host: ENV['DB_HOST'],
        port: ENV['DB_PORT'],
        dbname: ENV['DB_NAME'],
        user: ENV['DB_USER'],
        password: ENV['DB_PASSWORD']
      )
      # setup_database
    end

    def process_documents(documents)
      documents.each do |doc|
        chunks = create_chunks(doc[:content])
        chunks.each do |chunk|
          embedding = generate_embedding(chunk)
          store_embedding(embedding, chunk, doc)
        end
      end
    end

    def find_similar(query_embedding, limit = 5)
      # puts "Finding similar documents for vector: #{query_embedding}"
      result = @conn.exec_params(<<-SQL, [query_embedding, limit])
          SELECT#{' '}
            content,
            url,
            section,
            metadata,
            1 - (embedding <=> $1) as similarity
          FROM embeddings
          ORDER BY embedding <=> $1
          LIMIT $2
      SQL
      puts "Found #{result.ntuples} similar documents"
      result
    rescue PG::Error => e
      puts "Database error in find_similar: #{e.message}"
      puts "Error details: #{e.result.error_message}" if e.respond_to?(:result)
      raise e
    end

    def generate_embedding(text)
      response = @client.embeddings(
        parameters: {
          model: 'text-embedding-ada-002',  # Changed to ada-002 for 1536 dimensions
          input: text
        }
      )

      embedding = response.dig('data', 0, 'embedding')
      return nil unless embedding

      "[#{embedding.join(',')}]"
    rescue StandardError => e
      puts "Error generating embedding: #{e.message}"
      puts  e.response
      nil
    end

    def setup_database
      @conn = PG.connect(
        host: ENV['DB_HOST'],
        port: ENV['DB_PORT'],
        dbname: ENV['DB_NAME'],
        user: ENV['DB_USER'],
        password: ENV['DB_PASSWORD']
      )

      # Enable pgvector extension
      @conn.exec('CREATE EXTENSION IF NOT EXISTS vector')

      # Drop existing index if exists
      @conn.exec('DROP INDEX IF EXISTS embeddings_vector_idx')

      # Drop and recreate embeddings table with correct vector size
      @conn.exec('DROP TABLE IF EXISTS embeddings')
      @conn.exec(<<-SQL)
        CREATE TABLE embeddings (
          id SERIAL PRIMARY KEY,
          embedding vector(#{VECTOR_SIZE}),
          content TEXT,
          document_id TEXT,
          section TEXT,
          url TEXT,
          metadata JSONB,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      SQL

      # Create index for similarity search
      @conn.exec('CREATE INDEX embeddings_vector_idx ON embeddings USING ivfflat (embedding vector_cosine_ops)')
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

    def store_embedding(embedding, chunk, document)
      return unless embedding

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

      begin
        @conn.exec_params(
          sql,
          [
            embedding,
            chunk,
            document[:id],
            document[:section],
            document[:url],
            document[:metadata].to_json
          ]
        )
      rescue StandardError => e
        puts "Error storing embedding: #{e.message}"
      end
    end
  end
end
