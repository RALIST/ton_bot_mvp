require_relative 'base_scraper'

module TonBot
  module Scrapers
    class TonScraper < BaseScraper
      BASE_URL = 'https://docs.ton.org'.freeze
      INITIAL_PATHS = %w[/v3/concepts/dive-into-ton/introduction /develop /participate /learn].freeze

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
        'ton_docs'
      end
    end
  end
end
