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
        context = find_relevant_context(question, question_embedding)
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

    def find_relevant_context(question, question_embedding)
      return [] unless question_embedding

      context_filter = determine_context_filter(question)
      
      # Try contextual search first
      similar_chunks = Embedding.contextual_search(
        query_embedding: question_embedding,
        context_filter: context_filter,
        limit: 5
      )
      
      # If not enough results, try hybrid search
      if similar_chunks.length < 3
        puts "Found only #{similar_chunks.length} contextual results, trying hybrid search..."
        hybrid_chunks = Embedding.hybrid_search(
          query_text: question,
          query_embedding: question_embedding,
          limit: 5 - similar_chunks.length
        )
        
        # Combine results, removing duplicates
        similar_chunks = (similar_chunks + hybrid_chunks).uniq(&:id)
      end
      
      # If still not enough results, supplement with raw documents
      if similar_chunks.length < 5
        puts "Found only #{similar_chunks.length} processed results, checking raw documents..."
        raw_docs = find_relevant_raw_documents(5 - similar_chunks.length)
        
        # Combine processed and raw results
        context = format_similar_chunks(similar_chunks)
        context += format_raw_documents(raw_docs)
        context.uniq { |c| c[:content] }
      else
        format_similar_chunks(similar_chunks)
      end
    end

    def determine_context_filter(question)
      filter = {}
      
      # Check if question is likely about code
      if question.downcase.match?(/\b(code|function|method|api|implementation|example|how to|usage)\b/)
        filter[:has_code] = true
      end
      
      # Detect specific sections from question
      case question.downcase
      when /\b(smart contract|contract|solidity|func|tvm)\b/
        filter[:section] = 'develop'
      when /\b(validator|validation|stake|mining)\b/
        filter[:section] = 'participate'
      when /\b(concept|architecture|design|blockchain|how\s+\w+\s+works)\b/
        filter[:section] = 'learn'
      end
      
      filter
    end

    def find_relevant_raw_documents(limit)
      RawDocument.unprocessed.order(created_at: :desc).limit(limit)
    end

    def format_similar_chunks(chunks)
      chunks.map do |chunk|
        {
          content: chunk.content,
          url: chunk.url,
          section: chunk.section,
          similarity: chunk.try(:similarity) || chunk.try(:combined_score)
        }
      end
    end

    def format_raw_documents(docs)
      docs.map do |doc|
        {
          content: doc.content,
          url: doc.url,
          section: doc.section
        }
      end
    end

    def generate_response(question, context)
      # Sort context by similarity if available
      sorted_context = context.sort_by { |c| -c[:similarity].to_f }
      
      context_text = sorted_context.map.with_index do |c, i|
        # Include relevance score in debug mode
        score_info = c[:similarity] ? " (relevance: #{(c[:similarity] * 100).round(2)}%)" : ''
        "Source #{i + 1} (#{c[:url]})#{score_info}:\n#{c[:content]}\n\n"
      end.join("\n")

      begin
        request_params = {
          messages: [{
            role: 'user',
            content: <<~PROMPT
              You are a TON blockchain expert assistant. Use the following context to answer the question.
              If you can't find the answer in the context, say so and provide a general response about TON blockchain. 
              Avoid showing to user that you are using some context for answer, try always to answer in human form.
              If the context includes code examples and the question is about implementation, include relevant code snippets in your answer.

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
          sources: sorted_context.map { |c| c[:url] }.uniq,
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
