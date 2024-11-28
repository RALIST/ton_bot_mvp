require_relative 'base_scraper'

module TonBot
  module Scrapers
    class TactScraper < BaseScraper
      BASE_URL = 'https://tact-lang.org'.freeze
      INITIAL_PATHS = %w[/docs/overview /docs/language /docs/cookbook /docs/examples].freeze

      def scrape_all
        puts "Starting recursive scraping from #{BASE_URL}"
        INITIAL_PATHS.each do |path|
          scrape_page(BASE_URL + path, BASE_URL)
        end
        puts "Scraping completed. Total pages processed: #{@processed_urls.size}"
        
        process_unprocessed_documents
      end

      private

      def source_name
        'tact_docs'
      end

      def extract_main_content(doc)
        # TACT docs typically have their main content in a div with specific class
        doc.at_css('.markdown') || doc.at_css('article') || super
      end

      def extract_section(url)
        # Extract section from URL path for better categorization
        path_parts = URI.parse(url).path.split('/')
        return 'general' unless path_parts[1] == 'docs'
        
        case path_parts[2]
        when 'overview'
          'tact/overview'
        when 'language'
          'tact/language'
        when 'cookbook'
          'tact/cookbook'
        when 'examples'
          'tact/examples'
        else
          'tact/general'
        end
      end

      def has_code_blocks?(element)
        # TACT docs use specific classes for code blocks
        element.css('pre, code, .prism-code').any?
      end
    end
  end
end
