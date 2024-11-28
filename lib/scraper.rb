require 'nokogiri'
require 'httparty'
require 'uri'
require 'pg'
require_relative 'jobs/embedding_processor_job'

module TonBot
  class Scraper
    BASE_URL = 'https://docs.ton.org'.freeze
    INITIAL_PATHS = %w[/v3/concepts/dive-into-ton/introduction /develop /participate /learn].freeze

    def initialize
      @processed_urls = Set.new
      @conn = setup_database
    end

    def scrape_all
      puts "Starting recursive scraping from #{BASE_URL}"
      INITIAL_PATHS.each do |path|
        scrape_page(BASE_URL + path)
      end
      puts "Scraping completed. Total pages processed: #{@processed_urls.size}"
      
      # Enqueue unprocessed documents for embedding generation
      process_unprocessed_documents
    end

    def process_unprocessed_documents
      sql = <<-SQL
        SELECT id FROM raw_documents 
        WHERE processed = false 
        ORDER BY created_at ASC
      SQL

      result = @conn.exec(sql)
      total = result.ntuples
      puts "Found #{total} unprocessed documents. Enqueueing for processing..."

      result.each_with_index do |row, index|
        EmbeddingProcessorJob.perform_async(row['id'])
        puts "Enqueued document #{index + 1} of #{total}" if (index + 1) % 10 == 0
      end

      puts "All documents have been enqueued for processing"
    end

    private

    def setup_database
      conn = PG.connect(
        host: ENV['DB_HOST'],
        port: ENV['DB_PORT'],
        dbname: ENV['DB_NAME'],
        user: ENV['DB_USER'],
        password: ENV['DB_PASSWORD']
      )

      # Create raw_documents table if not exists
      conn.exec(<<-SQL)
        CREATE TABLE IF NOT EXISTS raw_documents (
          id SERIAL PRIMARY KEY,
          url TEXT UNIQUE,
          title TEXT,
          content TEXT,
          html_content TEXT,
          section TEXT,
          metadata JSONB,
          processed BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      SQL

      conn
    end

    def scrape_page(url)
      return if @processed_urls.include?(url) || !valid_url?(url)

      puts "Scraping: #{url}"
      @processed_urls.add(url)

      begin
        response = HTTParty.get(url)
        return unless response.success?

        doc = Nokogiri::HTML(response.body)
        store_document(doc, url)
        find_and_queue_links(doc, url)
      rescue StandardError => e
        puts "Error scraping #{url}: #{e.message}"
      end
    end

    def valid_url?(url)
      uri = URI.parse(url)
      uri.host == URI.parse(BASE_URL).host && 
        !url.end_with?('.png', '.jpg', '.jpeg', '.gif', '.pdf', '.zip') &&
        !url.include?('#')
    rescue URI::InvalidURIError
      false
    end

    def store_document(doc, url)
      # Remove navigation elements but keep the HTML structure
      doc.css('nav, footer, script, style').each(&:remove)
      main_content = doc.at_css('main')
      return unless main_content

      title = extract_title(doc)
      section = extract_section(url)
      metadata = {
        subsection: extract_subsection(doc),
        has_code: has_code_blocks?(main_content),
        headings: extract_headings(doc),
        last_updated: extract_last_updated(doc)
      }

      sql = <<-SQL
        INSERT INTO raw_documents (url, title, content, html_content, section, metadata)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (url) 
        DO UPDATE SET 
          title = EXCLUDED.title,
          content = EXCLUDED.content,
          html_content = EXCLUDED.html_content,
          section = EXCLUDED.section,
          metadata = EXCLUDED.metadata,
          processed = FALSE,
          updated_at = CURRENT_TIMESTAMP
        RETURNING id
      SQL

      result = @conn.exec_params(
        sql,
        [
          url,
          title,
          clean_content(main_content),
          main_content.to_html,
          section,
          metadata.to_json
        ]
      )
      
      result[0]['id']
    rescue StandardError => e
      puts "Error storing document #{url}: #{e.message}"
      nil
    end

    def find_and_queue_links(doc, current_url)
      doc.css('a').each do |link|
        href = link['href']
        next unless href

        absolute_url = make_absolute_url(href, current_url)
        next unless absolute_url

        scrape_page(absolute_url)
      end
    end

    def make_absolute_url(href, current_url)
      return nil if href.nil? || href.empty?
      
      uri = URI.parse(href)
      return href if uri.absolute? && uri.host == URI.parse(BASE_URL).host
      return URI.join(BASE_URL, href).to_s if uri.path&.start_with?('/')
      return URI.join(current_url, href).to_s
    rescue URI::InvalidURIError
      nil
    end

    def extract_title(doc)
      doc.at_css('h1')&.text&.strip || doc.title&.strip
    end

    def extract_section(url)
      path_parts = URI.parse(url).path.split('/')
      path_parts[1..2].join('/') rescue 'general'
    end

    def extract_subsection(doc)
      doc.at_css('h2')&.text&.strip
    end

    def extract_headings(doc)
      doc.css('h1, h2, h3').map(&:text).map(&:strip)
    end

    def extract_last_updated(doc)
      # Add custom logic to extract last updated date if available
      nil
    end

    def clean_content(element)
      element.text.strip.gsub(/\s+/, ' ')
    end

    def has_code_blocks?(element)
      !element.css('pre, code').empty?
    end
  end
end
