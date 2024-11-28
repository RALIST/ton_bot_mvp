require_relative 'ton_scraper'
require_relative 'tact_scraper'

module TonBot
  module Scrapers
    class ScraperManager
      def initialize
        @scrapers = [
          TonScraper.new,
          TactScraper.new
        ]
      end

      def scrape_all
        @scrapers.each do |scraper|
          puts "\nStarting scraper: #{scraper.class.name}"
          scraper.scrape_all
        end
      end

      def self.sources
        ['ton_docs', 'tact_docs']
      end
    end
  end
end
