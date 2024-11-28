require 'anthropic'
require 'openai'
require 'redis'
require 'json'

module TonBot
  class Bot
    def initialize
      @claude = Anthropic::Client.new
      @openai = OpenAI::Client.new
      @embeddings = Embeddings.new
      @redis = Redis.new(url: ENV['REDIS_URL'])
      @cache_ttl = 3600 # 1 hour
      @conn = PG.connect(
        host: ENV['DB_HOST'],
        port: ENV['DB_PORT'],
        dbname: ENV['DB_NAME'],
        user: ENV['DB_USER'],
        password: ENV['DB_PASSWORD']
      )

      puts 'Bot initialized successfully'
    end

    def answer_question(question)
      puts "\nProcessing question: #{question}"

      # Check cache first
      cache_key = "ton_bot:#{question.downcase.strip}"
      cached_response = @redis.get(cache_key)
      if cached_response
        puts 'Cache hit, returning cached response'
        return JSON.parse(cached_response)
      end

      puts 'Cache miss, generating new response'

      # Generate embedding for the question
      puts 'Generating question embedding...'
      question_embedding = generate_question_embedding(question)

      if question_embedding.nil?
        return {
          error: 'Failed to generate question embedding',
          timestamp: Time.now.utc.iso8601
        }
      end

      # Find relevant context
      puts 'Finding relevant context...'
      begin
        context = find_relevant_context(question_embedding)
        puts "Found #{context.length} relevant context items"
      rescue StandardError => e
        puts "Error finding relevant context: #{e.message}"
        return {
          error: "Failed to find relevant context: #{e.message}",
          timestamp: Time.now.utc.iso8601
        }
      end

      # Generate response using Claude
      response = generate_response(question, context)

      # Cache the response if it doesn't contain an error
      unless response[:error]
        puts 'Caching successful response'
        cache_response(cache_key, response)
      end

      response
    end

    private

    def generate_question_embedding(question)
      @embeddings.generate_embedding(question)
    rescue StandardError => e
      puts "Error generating question embedding: #{e.message}"
      nil
    end

    def find_relevant_context(question_embedding)
      return [] unless question_embedding

      # First try to find context from processed embeddings
      similar_chunks = @embeddings.find_similar(question_embedding, 5)
      
      # If we don't have enough processed embeddings, supplement with raw documents
      if similar_chunks.ntuples < 5
        puts "Found only #{similar_chunks.ntuples} processed embeddings, checking raw documents..."
        raw_docs = find_relevant_raw_documents(5 - similar_chunks.ntuples)
        
        # Combine processed and raw results
        context = format_similar_chunks(similar_chunks)
        context += format_raw_documents(raw_docs)
        context.uniq { |c| c[:content] }
      else
        format_similar_chunks(similar_chunks)
      end
    end

    def find_relevant_raw_documents(limit)
      # Simple keyword-based fallback when embeddings aren't ready
      sql = <<-SQL
        SELECT 
          content,
          url,
          section,
          metadata,
          created_at
        FROM raw_documents
        WHERE processed = false
        ORDER BY created_at DESC
        LIMIT $1
      SQL

      @conn.exec_params(sql, [limit])
    end

    def format_similar_chunks(chunks)
      chunks.map do |chunk|
        {
          content: chunk['content'],
          url: chunk['url'],
          section: chunk['section']
        }
      end
    end

    def format_raw_documents(docs)
      docs.map do |doc|
        {
          content: doc['content'],
          url: doc['url'],
          section: doc['section']
        }
      end
    end

    def generate_response(question, context)
      context_text = context.map do |c|
        "Source (#{c[:url]}):\n#{c[:content]}\n\n"
      end.join("\n")

      begin
        request_params = {
          messages: [{
            role: 'user',
            content: <<~PROMPT
              You are a TON blockchain expert assistant. Use the following context to answer the question.
              If you can't find the answer in the context, say so and provide a general response about TON blockchain. Avoid showing to user that you are using some context for answer, try always to answer in human form.

              Context:
              #{context_text}

              Question: #{question}
            PROMPT
          }],
          model: 'claude-3-sonnet-20240229',
          max_tokens: 4096,
          temperature: 0.7
        }

        puts "Response request params: #{JSON.pretty_generate(request_params)}"
        response = @claude.messages(parameters: request_params)
        puts "Response: #{JSON.pretty_generate(response)}"

        {
          answer: response['content']&.first&.dig('text'),
          sources: context.map { |c| c[:url] }.uniq,
          timestamp: Time.now.utc.iso8601
        }
      rescue StandardError => e
        puts "Error generating response: #{e.message}"
        puts "Full error: #{e.inspect}"
        if e.respond_to?(:response)
          begin
            puts "Response body: #{e.response.body}"
          rescue StandardError
            nil
          end
        end
        {
          error: "Failed to generate response: #{e.message}",
          timestamp: Time.now.utc.iso8601
        }
      end
    end

    def cache_response(key, response)
      @redis.setex(key, @cache_ttl, response.to_json)
    rescue StandardError => e
      puts "Error caching response: #{e.message}"
    end
  end
end
